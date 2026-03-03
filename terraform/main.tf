terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
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

locals {
  vpc_id            = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default.id
  ssh_allowed_cidrs = var.allowed_ssh_cidr != null ? var.allowed_ssh_cidr : ["${chomp(data.http.my_public_ip.response_body)}/32"]
  s3_bucket_name    = "${var.project_name}-${var.environment}-appfiles-${random_id.bucket_suffix.dec}"

  subnet_id = var.subnet_id != null ? var.subnet_id : (
    length(data.aws_subnets.default.ids) > 0 ? data.aws_subnets.default.ids[0] : null
  )

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
      condition     = local.subnet_id != null
      error_message = "No valid subnet ID found. Either provide subnet_id variable or ensure your VPC has public subnets with map-public-ip-on-launch enabled."
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

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = local.s3_bucket_name

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-files"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

module "iam_assumable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role             = true
  create_instance_profile = true

  role_name         = "${var.project_name}-ec2-role-${var.environment}"
  role_requires_mfa = false

  trusted_role_services = [
    "ec2.amazonaws.com"
  ]

  number_of_custom_role_policy_arns = 1

  custom_role_policy_arns = [
    aws_iam_policy.s3_access.arn
  ]

  tags = {
    Name        = "${var.project_name}-iam"
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
          module.s3_bucket.s3_bucket_arn,
          "${module.s3_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = module.iam_assumable_role.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
  iam_instance_profile   = module.iam_assumable_role.iam_instance_profile_name
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_eip_association" "web_eip_association" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web_eip.id
}

resource "aws_ssm_document" "app_setup" {
  name            = "chucknoris-setup-${var.environment}"
  document_type   = "Command"
  document_format = "YAML"

  content = templatefile("${path.module}/ssm-document.yaml", {
    S3Bucket = module.s3_bucket.s3_bucket_id
    S3Object = var.s3_object_name
    Region   = var.region
  })
}

resource "null_resource" "upload_app_files" {
  depends_on = [module.s3_bucket]

  provisioner "local-exec" {
    command = "tar -czf /tmp/app-files.tar.gz ${path.module}/../app ${path.module}/../docker && aws s3 cp /tmp/app-files.tar.gz s3://${module.s3_bucket.s3_bucket_id}/${var.s3_object_name} --region ${var.region} && rm -f /tmp/app-files.tar.gz"
  }
}

resource "aws_ssm_association" "app_setup" {
  name = aws_ssm_document.app_setup.name

  depends_on = [null_resource.upload_app_files]

  targets {
    key    = "InstanceIds"
    values = [aws_instance.web.id]
  }

  parameters = {
    S3Bucket = module.s3_bucket.s3_bucket_id
    S3Object = var.s3_object_name
    Region   = var.region
  }
}

resource "null_resource" "app_setup_trigger" {
  depends_on = [aws_ssm_association.app_setup]

  triggers = {
    app_files_hash = local.app_files_hash
  }

  provisioner "local-exec" {
    command = "echo 'SSM Document applied with hash: ${local.app_files_hash}'"
  }
}
