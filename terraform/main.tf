terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_vpc" "custom" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_route_tables" "public" {
  vpc_id = local.vpc_id

  filter {
    name   = "route.destination-cidr-block"
    values = ["0.0.0.0/0"]
  }

  filter {
    name   = "route.gateway-id"
    values = ["igw-*"]
  }
}

data "aws_route_table" "public_main" {
  count  = length(data.aws_route_tables.public.ids)
  vpc_id = local.vpc_id

  filter {
    name   = "association.main"
    values = ["true"]
  }

  filter {
    name   = "route.destination-cidr-block"
    values = ["0.0.0.0/0"]
  }

  filter {
    name   = "route.gateway-id"
    values = ["igw-*"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

locals {
  vpc_id            = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default.id
  public_subnet_ids = length(data.aws_route_table.public_main) > 0 ? [for assoc in data.aws_route_table.public_main[0].associations : assoc.subnet_id if assoc.subnet_id != null] : []
  ssh_allowed_cidrs = var.allowed_ssh_cidr != null ? var.allowed_ssh_cidr : ["${chomp(data.http.my_public_ip.response_body)}/32"]
  s3_bucket_name    = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  auto_subnet_id    = length(local.public_subnet_ids) > 0 ? local.public_subnet_ids[0] : data.aws_subnets.default.ids[0]
  subnet_id         = var.subnet_id != null ? var.subnet_id : local.auto_subnet_id
  app_files_hash = sha256(join("", [
    filesha256("${path.module}/../app/server.py"),
    filesha256("${path.module}/../app/requirements.txt"),
    filesha256("${path.module}/../app/templates/index.html"),
    filesha256("${path.module}/../app/static/style.css"),
    filesha256("${path.module}/../docker/Dockerfile"),
    filesha256("${path.module}/../docker/docker-compose.yml"),
    filesha256("${path.module}/../docker/nginx.conf"),
  ]))
}

resource "null_resource" "validate_subnet" {
  triggers = {
    subnet_id = local.subnet_id
  }

  lifecycle {
    precondition {
      condition     = var.subnet_id != null ? true : length(local.public_subnet_ids) > 0
      error_message = var.subnet_id != null ? "Using custom subnet ID." : "No public subnets found with Internet Gateway route in VPC. Ensure your VPC has subnets with public IP assignment and route to IGW (0.0.0.0/0)."
    }
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "app_files" {
  bucket = local.s3_bucket_name
  tags = {
    Name        = "${var.project_name}-files"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "app_files" {
  bucket = aws_s3_bucket.app_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_files" {
  bucket = aws_s3_bucket.app_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-policy"
  description = "Policy to access S3 bucket for app files"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_files.arn,
          "${aws_s3_bucket.app_files.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-profile-${var.environment}"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-sg-${var.environment}"
  description = "Security group for ${var.project_name} - managed by Terraform"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH (restricted to deployer IP)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ssh_allowed_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_eip" "web_eip" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-eip-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "null_resource" "app_setup" {
  depends_on = [aws_instance.web]

  connection {
    type        = "ssh"
    host        = aws_instance.web.public_ip
    user        = "ec2-user"
    private_key = var.ssh_private_key_path != "" ? file(var.ssh_private_key_path) : null
  }

  provisioner "file" {
    source      = "${path.module}/../scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash -c 'chmod +x /tmp/setup.sh && S3_BUCKET=\"${aws_s3_bucket.app_files.bucket}\" S3_OBJECT=\"${var.s3_object_name}\" REGION=\"${var.region}\" /tmp/setup.sh && rm /tmp/setup.sh'",
    ]
  }

  triggers = {
    script_sha256  = sha256(file("${path.module}/../scripts/setup.sh"))
    app_files_hash = local.app_files_hash
    instance_id    = aws_instance.web.id
  }
}

resource "aws_eip_association" "web_eip_association" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web_eip.id
}
