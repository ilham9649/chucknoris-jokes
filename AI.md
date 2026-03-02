# Chuck Norris Jokes - DevOps Assessment

## Project Overview

This project is a **DevOps Assessment** that demonstrates a fully automated deployment pipeline using Infrastructure as Code (IaC) and configuration management best practices.

### Goal
Build and deploy a Chuck Norris jokes web application using:
- Python Flask application
- Docker containerization (2 containers)
- Terraform for infrastructure (AWS)
- Automated file change detection and deployment
- Remote-exec provisioners for server setup

### Application Features
- Fetches random Chuck Norris jokes from [Chuck Norris API](https://api.chucknorris.io/)
- Simple, responsive HTML UI with refresh button
- Health check endpoint
- RESTful design

## Architecture

### Components

1. **Application Layer** (`app/`)
   - Python Flask web server
   - HTML template with CSS styling
   - Fetches jokes from Chuck Norris API

2. **Containerization** (`docker/`)
   - **2 Containers**:
     - `app`: Flask application (custom Alpine + Python)
     - `nginx`: Official Nginx Alpine image (reverse proxy)
   - Multi-stage Docker builds
   - Docker Compose for orchestration

3. **Infrastructure** (`terraform/`)
   - **AWS Resources**:
     - S3 Bucket (encrypted, versioned)
     - IAM Role & Policies (minimal permissions)
     - EC2 Instance (t2.micro)
     - Elastic IP (static public IP)
     - Security Group (auto-detects deployer IP)
     - Default VPC & Subnet

4. **Deployment** (`scripts/`)
   - `setup.sh`: Server setup and application deployment script
   - Uploads via Terraform `provisioner "file"`
   - Executed via Terraform `provisioner "remote-exec"`

### Deployment Workflow

```
1. Developer modifies app/ or docker/ files
2. Runs: terraform apply
3. Terraform detects file changes (SHA256 hash)
4. Files are zipped and uploaded to S3
5. EC2 instance is created/recreated
6. Terraform uploads scripts/setup.sh via provisioner "file"
7. Terraform executes setup.sh via provisioner "remote-exec"
8. Setup script downloads files from S3
9. Docker Compose builds and starts containers
10. Application accessible via Elastic IP
```

## Technologies Used

| Technology | Purpose |
|------------|---------|
| **Python 3.11** | Flask application |
| **Flask 3.0** | Web framework |
| **Docker** | Containerization |
| **Docker Compose** | Multi-container orchestration |
| **Nginx** | Reverse proxy (official image) |
| **Terraform 1.0+** | Infrastructure as Code |
| **AWS S3** | File storage |
| **AWS EC2** | Compute |
| **AWS IAM** | Security |
| **Bash** | Deployment scripts |

## Security Features

### 1. Auto SSH Restriction
- Security group automatically detects deployer's public IP
- Only allows SSH from that IP (auto-updated)
- Prevents unauthorized access

### 2. S3 Encryption
- AES256 encryption at rest
- Versioning enabled
- IAM role with minimal S3 permissions

### 3. IAM Least Privilege
- EC2 instance can only access specific S3 bucket
- SSM managed policy for basic AWS access

### 4. Encrypted EBS
- Root volume encrypted with AWS managed keys
- GP3 storage type (better performance)

### 5. Static IP
- Elastic IP ensures consistent public IP
- IP remains static across instance restarts

## Best Practices Implemented

### Infrastructure as Code (IaC)
- All AWS resources defined in Terraform
- Version controlled
- Idempotent operations
- State management

### Containerization
- **Multi-stage builds**: Smaller final images
- **Official Nginx image**: No customization needed
- **Alpine Linux**: Lightweight, minimal attack surface
- **2-container separation**: App and proxy are isolated

### Automated Deployment
- Remote-exec provisioner for EC2 initialization
- No manual SSH needed after initial setup
- Health checks ensure application is running
- File change detection triggers automatic deployment

### File Change Detection
- SHA256 hash of all app/docker files
- Triggers re-deployment when files change
- Efficient: only deploys when files change
- Hash includes setup script changes

### Security by Default
- Secrets excluded from git (`.gitignore`)
- Example variable files for sensitive values
- Auto-detection of deployer IP for SSH
- Encrypted S3 bucket with versioning

### Provisioners
- `provisioner "file"`: Uploads setup script to EC2
- `provisioner "remote-exec"`: Executes setup script remotely
- `triggers`: Force re-run on script or file changes
- Re-runs on instance recreation

## Project Structure

```
chucknoris-jokes/
├── app/                    # Flask Application
│   ├── server.py
│   ├── templates/index.html
│   ├── static/style.css
│   └── requirements.txt
├── docker/                   # Container Config
│   ├── Dockerfile           # Flask app container
│   ├── nginx.conf          # Nginx proxy config
│   └── docker-compose.yml   # 2 containers
├── terraform/                # IaC
│   ├── main.tf             # AWS resources
│   ├── variables.tf        # Configuration
│   ├── outputs.tf          # Outputs
│   ├── terraform.tfvars    # Dev environment variables
│   └── environments/
│       └── dev.tfvars    # Alternative env config (not used)
├── scripts/                  # Automation
│   └── setup.sh          # Server deployment script
├── .gitignore              # Exclude secrets
└── AI.md                   # This file
```

## Key Implementation Details

### File Change Detection Mechanism

```hcl
# Terraform calculates hash of all source files
locals {
  app_files_hash = sha256(join("", [
    filesha256("../app/server.py"),
    filesha256("../app/requirements.txt"),
    filesha256("../app/templates/index.html"),
    filesha256("../app/static/style.css"),
    filesha256("../docker/Dockerfile"),
    filesha256("../docker/docker-compose.yml"),
    filesha256("../docker/nginx.conf"),
  ]))
}

# Triggers re-deployment when hash changes
resource "null_resource" "app_setup" {
  triggers = {
    script_sha256  = sha256(file("../scripts/setup.sh"))
    app_files_hash = local.app_files_hash
    instance_id    = aws_instance.web.id
  }
}
```

### Remote-Exec Provisioner Flow

```hcl
resource "null_resource" "app_setup" {
  depends_on = [aws_instance.web]

  # Upload setup script to EC2
  provisioner "file" {
    source      = "${path.module}/../scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }

  # Execute setup script remotely
  provisioner "remote-exec" {
    inline = [
      "sudo bash -c 'chmod +x /tmp/setup.sh && S3_BUCKET=\"${aws_s3_bucket.app_files.bucket}\" S3_OBJECT=\"${var.s3_object_name}\" REGION=\"${var.region}\" /tmp/setup.sh && rm /tmp/setup.sh'",
    ]
  }

  # Re-run when files or instance changes
  triggers = {
    script_sha256  = sha256(file("${path.module}/../scripts/setup.sh"))
    app_files_hash = local.app_files_hash
    instance_id    = aws_instance.web.id
  }
}
```

### Setup Script Flow

```bash
1. Install dependencies (yum-utils, curl, git)
2. Install Docker (amazon-linux-extras)
3. Install Docker Compose (standalone from GitHub)
4. Download files from S3 (app-files.tar.gz)
5. Extract to /opt/chucknoris-jokes
6. Run docker-compose build
7. Stop old containers (docker-compose down)
8. Start new containers (docker-compose up -d)
9. Health check (wait for /health endpoint)
10. Display application URL
```

## Cost Estimation

| Resource | Cost (Monthly) |
|----------|----------------|
| EC2 t2.micro | ~$8.76 |
| Elastic IP | ~$3.60 |
| EBS 8GB | ~$0.64 |
| S3 Storage (~1GB) | ~$0.02 |
| Data Transfer | Free tier: 100GB |
| **Total** | **~$13 USD** |

**Free Tier**: EC2 and EBS are free for 12 months

## Deployment Commands

### Quick Deploy
```bash
cd terraform

# Configure your AWS key pair and other settings in terraform.tfvars

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment
terraform apply
```

### Manual Deploy
```bash
cd terraform

# Initialize (first time only)
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply -auto-approve

# Get Elastic IP
terraform output elastic_ip

# Access application
curl http://<ELASTIC-IP>
```

### Re-deploy on File Changes
```bash
# Modify app/ or docker/ files
cd terraform

# Terraform detects hash changes and re-deploys automatically
terraform apply -auto-approve
```

### Clean Up
```bash
cd terraform

# Destroy all resources
terraform destroy
```

## Customization

### Change AWS Region
```hcl
# terraform/terraform.tfvars
region = "us-east-1"
```

### Use Different Instance Type
```hcl
# terraform/terraform.tfvars
instance_type = "t3.small"
```

### Use Different SSH Key
```hcl
# terraform/terraform.tfvars
key_name = "your-key-pair-name"
ssh_private_key_path = "/path/to/your/private-key.pem"
```

### Deploy Different Application
1. Replace `app/` with your application
2. Update `docker/Dockerfile` if needed
3. Update `docker/nginx.conf` if needed
4. File changes are auto-detected on next `terraform apply`

## Troubleshooting

### Issue: File change not detected
**Solution**: Manually trigger re-deployment:
```bash
cd terraform
terraform taint null_resource.app_setup
terraform apply
```

### Issue: Application not accessible
**Solution**: Check instance status and logs:
```bash
# SSH into EC2
ssh -i /path/to/key.pem ec2-user@<ELASTIC-IP>

# Check containers
docker ps

# Check logs
docker logs chucknoris-jokes-app
docker logs chucknoris-jokes-nginx

# Check docker-compose logs
cd /opt/chucknoris-jokes/docker
docker-compose logs
```

### Issue: Elastic IP not attaching
**Solution**: Check EIP association:
```bash
cd terraform
terraform output elastic_ip

# Verify association
aws ec2 describe-addresses --allocation-ids <ALLOCATION-ID>
```

### Issue: Docker Compose not found
**Solution**: Manual installation via SSH:
```bash
ssh -i /path/to/key.pem ec2-user@<ELASTIC-IP>

# Check docker-compose
which docker-compose

# Manually install if needed
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## Learning Outcomes

This project demonstrates:

✅ **Infrastructure as Code**: Terraform manages all AWS resources
✅ **Containerization**: Multi-stage Docker builds with 2-container setup
✅ **Automation**: Remote-exec provisioner eliminates manual configuration
✅ **Security**: Auto SSH restriction, encryption, IAM least privilege
✅ **Change Detection**: Automatic file change detection with hash triggers
✅ **Scalability**: Elastic IP ensures consistent access
✅ **Best Practices**: Separation of concerns, official images, no hardcoded secrets
✅ **Cost Optimization**: Free tier resources, efficient container design
✅ **Documentation**: Complete AI.md, inline comments
✅ **Flexible Deployment**: Triggers allow re-deployment without recreation

## Future Enhancements

1. **HTTPS**: Add SSL certificates (Let's Encrypt or ACM)
2. **CI/CD**: GitHub Actions for automated deployments
3. **Monitoring**: CloudWatch logs and metrics
4. **Auto-scaling**: Auto-scaling group for high availability
5. **Blue-green deployment**: Zero-downtime updates
6. **Multiple environments**: Staging and production configs
7. **ECR**: Container registry for image versioning
8. **Load Balancer**: Application Load Balancer for distribution

## Why Docker Compose Build vs ECR

### Current Approach: `docker-compose build` on EC2

**Justification for this project:**
- **Single instance deployment**: Only one EC2 instance needs images
- **Small/simple app**: Fast build times on EC2
- **Development environment**: Rapid iteration more important than optimization
- **No CI/CD pipeline**: Manual deployment means build-and-deploy in one step
- **Cost efficiency**: No ECR storage/transfer costs
- **Simplicity**: Easier to understand and debug

**Pros:**
- Simpler - no registry management needed
- Faster for small projects (no push/pull overhead)
- No additional AWS costs
- Works well for single-instance deployments
- Easier to debug (build logs visible during deployment)

**Cons:**
- Slower builds (EC2 resources may be limited)
- Builds happen repeatedly on every deployment
- No image versioning/history
- Difficult to scale (other instances can't reuse built images)
- Image rebuilds waste compute resources

### When ECR Would Be Better

Consider ECR if:
- Multiple instances/containers need same images
- Building is slow or resource-intensive
- Need image versioning and rollback capabilities
- Implementing CI/CD pipeline
- Deploying to multiple environments (dev/staging/prod)
- Need image scanning and security compliance

## Assessment Criteria Met

| Requirement | Status |
|------------|--------|
| Python/NodeJS application | ✅ Python Flask |
| Displays Chuck Norris jokes | ✅ Fetches from API |
| Simple HTML page | ✅ Responsive UI |
| Runs in Docker container | ✅ Multi-container setup |
| Alpine Linux base image | ✅ Alpine 3.19 |
| Webserver as proxy | ✅ Official Nginx |
| IaC (Terraform) | ✅ All AWS resources |
| IaC solution is reusable | ✅ Variables, modular design |
| No pre-built Docker images | ✅ Built from source on EC2 |
| README with manual | ✅ Comprehensive docs (AI.md) |
| Use existing SSH key | ✅ Configured via variables |
| Auto-detect deployer IP | ✅ Security group restriction |
| S3 for file storage | ✅ Encrypted, versioned |
| File change detection | ✅ SHA256 hash triggers |
| Automated deployment | ✅ Remote-exec provisioners |

---

**Built by AI** - This project was created by an AI assistant for DevOps assessment purposes.

**Date**: 2026-03-02  
**Version**: 2.0.0 (Updated for remote-exec deployment)
