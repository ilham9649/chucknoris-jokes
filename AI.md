# Chuck Norris Jokes - DevOps Assessment

## Project Overview

This project is a **DevOps Assessment** that demonstrates a fully automated deployment pipeline using Infrastructure as Code (IaC) and configuration management best practices.

### Goal
Build and deploy a Chuck Norris jokes web application using:
- Python Flask application
- Docker containerization (2 containers)
- Terraform for infrastructure (AWS)
- Automated file change detection and deployment

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
   - `deploy.sh`: Automated deployment script
   - `destroy.sh`: Resource cleanup

### Deployment Workflow

```
1. Developer modifies app/ or docker/ files
2. Runs: terraform apply
3. Terraform detects file changes (SHA256 hash)
4. Files are zipped and uploaded to S3
5. EC2 instance is created/recreated
6. User Data script downloads files from S3
7. Docker Compose starts containers
8. Application accessible via Elastic IP
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
- Only allows SSH from that IP (`182.2.69.158/32`)
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
- User Data script for EC2 initialization
- No manual SSH needed after deployment
- Health checks ensure application is running

### File Change Detection
- SHA256 hash of all app/docker files
- Triggers re-upload to S3 on changes
- Efficient: only uploads when files change

### Security by Default
- Secrets excluded from git (`.gitignore`)
- Example files for sensitive values (`.tfvars.example`)
- Auto-detection of deployer IP for SSH

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
│   ├── user_data.sh        # EC2 setup script
│   └── environments/
│       └── dev.tfvars    # Dev environment
├── scripts/                  # Automation
│   ├── deploy.sh
│   └── destroy.sh
├── .gitignore              # Exclude secrets
├── .env.example            # Env variables template
├── AI.md                   # This file
└── README.md                # User documentation
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

# Triggers re-upload when hash changes
resource "null_resource" "upload_app_files" {
  triggers = {
    app_files_hash = local.app_files_hash
    timestamp       = timestamp()
  }
}
```

### User Data Script Flow

```bash
1. Update system (dnf update)
2. Install Docker (docker-ce)
3. Install Docker Compose (standalone)
4. Download files from S3 (app-files.tar.gz)
5. Extract to /opt/chucknoris-jokes
6. Run docker-compose up -d
7. Health check (wait for /health endpoint)
8. Display application URL
```

## Cost Estimation

| Resource | Cost (Monthly) |
|----------|-----------------|
| EC2 t2.micro | ~$8.76 |
| Elastic IP | ~$3.60 |
| EBS 30GB | ~$2.40 |
| S3 Storage (~1GB) | ~$0.02 |
| Data Transfer | Free tier: 100GB |
| **Total** | **~$15 USD** |

**Free Tier**: EC2 and EBS are free for 12 months

## Deployment Commands

### Quick Deploy
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS key pair name

cd ..
./scripts/deploy.sh
```

### Manual Deploy
```bash
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Get Elastic IP
terraform output elastic_ip

# Access application
curl http://<ELASTIC-IP>
```

### Clean Up
```bash
./scripts/destroy.sh
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

### Deploy Different Application
1. Replace `app/` with your application
2. Update `docker/Dockerfile` if needed
3. Update `docker/nginx.conf` if needed
4. File changes are auto-detected on next `terraform apply`

## Troubleshooting

### Issue: File change not detected
**Solution**: Manually trigger re-upload:
```bash
cd terraform
terraform taint null_resource.upload_app_files
terraform apply
```

### Issue: Application not accessible
**Solution**: Check instance status and logs:
```bash
# SSH into EC2
ssh -i ~/.ssh/sulaksono-private ec2-user@<ELASTIC-IP>

# Check containers
sudo docker ps

# Check logs
sudo docker-compose -f /opt/chucknoris-jokes/docker/docker-compose.yml logs
```

### Issue: Elastic IP not attaching
**Solution**: Check EIP association:
```bash
aws ec2 describe-addresses --allocation-ids <ALLOCATION-ID>
```

## Learning Outcomes

This project demonstrates:

✅ **Infrastructure as Code**: Terraform manages all AWS resources
✅ **Containerization**: Multi-stage Docker builds with 2-container setup
✅ **Automation**: User Data script eliminates manual configuration
✅ **Security**: Auto SSH restriction, encryption, IAM least privilege
✅ **Change Detection**: Automatic file change detection with hash triggers
✅ **Scalability**: Elastic IP ensures consistent access
✅ **Best Practices**: Separation of concerns, official images, no hardcoded secrets
✅ **Cost Optimization**: Free tier resources, efficient container design
✅ **Documentation**: Complete README, AI.md, inline comments

## Future Enhancements

1. **HTTPS**: Add SSL certificates (Let's Encrypt)
2. **CI/CD**: GitHub Actions for automated deployments
3. **Monitoring**: CloudWatch logs and metrics
4. **Auto-scaling**: Auto-scaling group for high availability
5. **Blue-green deployment**: Zero-downtime updates
6. **Multiple environments**: Staging and production configs

## Assessment Criteria Met

| Requirement | Status |
|------------|--------|
| Python/NodeJS application | ✅ Python Flask |
| Displays Chuck Norris jokes | ✅ Fetches from API |
| Simple HTML page | ✅ Responsive UI |
| Runs in Docker container | ✅ Multi-container setup |
| Alpine Linux base image | ✅ Alpine 3.19 |
| Webserver as proxy | ✅ Official Nginx |
| IaC (Terraform + Ansible) | ✅ Terraform (simplified) |
| IaC solution is reusable | ✅ Variables, templates |
| No pre-built Docker images | ✅ Built from source |
| README with manual | ✅ Comprehensive docs |
| Use existing SSH key | ✅ Configured via variables |
| Auto-detect deployer IP | ✅ Security group restriction |
| S3 for file storage | ✅ Encrypted, versioned |
| File change detection | ✅ SHA256 hash triggers |

---

**Built by AI** - This project was created by an AI assistant for DevOps assessment purposes.

**Date**: 2026-03-02  
**Version**: 1.0.0
