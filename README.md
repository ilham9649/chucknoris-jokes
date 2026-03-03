# Chuck Norris Jokes - DevOps Assessment

A fully automated deployment pipeline demonstrating Infrastructure as Code (IaC) and configuration management best practices using Python Flask, Docker, Terraform, and AWS.

## Overview

This project displays random Chuck Norris jokes fetched from [Chuck Norris API](https://api.chucknorris.io/) and demonstrates:

- **Terraform** - Infrastructure as Code (AWS EC2, Security Groups, S3, IAM)
- **Docker** - Containerization with 2 containers (Flask app + Nginx proxy)
- **AWS SSM** - Secure instance access and script execution without SSH keys
- **SSM Document + Association** - Automated server configuration
- **S3** - Application file storage
- **Auto SSH Security** - Security group auto-detects your public IP (optional)

## Architecture

```mermaid
graph LR
    subgraph Local["Developer Machine"]
        TF[Terraform]
        APP[App Files]
    end

    subgraph AWS["AWS Cloud"]
        S3[S3 Bucket]
        EIP[Elastic IP]
        EC2[EC2 Instance]
        SSM[SSM]

        subgraph EC2_INSIDE["Inside EC2"]
            DOCKER[Docker Compose]
            NGINX[Nginx<br/>:80]
            FLASK[Flask App<br/>:5000]
        end
    end

    USER[User] -->|HTTP| EIP
    EIP --> EC2
    SG[Security Group] --> EC2
    TF -->|Upload| S3
    TF -->|Trigger| SSM
    SSM -->|Deploy| EC2
    S3 -->|Download| EC2
    DOCKER --> NGINX
    DOCKER --> FLASK
    NGINX <--> FLASK
    FLASK -->|API| API[Chuck Norris API]

    style TF fill:#f96
    style S3 fill:#f9f
    style EC2 fill:#9f9
    style SG fill:#f96
    style SSM fill:#f96
    style NGINX fill:#99f
    style FLASK fill:#99f
```

### Architecture Flow

1. **Deployment**: Developer runs `terraform apply` → uploads files to S3 → creates SSM Document & Association
2. **Configuration**: SSM Association triggers SSM Document on EC2 → downloads files → runs Docker Compose
3. **Access**: User accesses app via Elastic IP → Nginx proxy → Flask app → Chuck Norris API
4. **Management**: AWS SSM for secure instance access (no SSH keys needed)

## Quick Start

### Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.14
- Docker >= 20.10 (for local testing)
- SSH key pair in AWS (optional, only needed for SSH access)
- AWS Session Manager plugin (recommended, for SSM access)

### Deployment

```bash
# 1. Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your own environment variables

# 2. Initialize and deploy
terraform init
terraform plan
terraform apply

# 3. Get Elastic IP
terraform output elastic_ip

# 4. Access application
curl http://<ELASTIC-IP>
# Or open in browser: http://<ELASTIC-IP>
```

## Configuration

Copy the example file and customize your settings:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Region
region            = "ap-southeast-3"

# EC2 Instance Type
instance_type     = "t3.nano"

# Project and Environment
project_name      = "chucknoris-jokes"
environment       = "dev"

# SSH Key Pair (optional - for SSH access only, not required for SSM)
# Create key pair in AWS EC2 console first
key_name          = "your-existing-key-pair-name"

# VPC Configuration (optional - leave null for default VPC)
vpc_id            = null

# Subnet Configuration (optional - leave null for auto-selection)
# Subnet must have public IP assignment enabled and route to Internet Gateway
subnet_id         = null

# SSH Access Security (optional - leave null for auto-detection)
# Auto-detects your current public IP or specify custom CIDR blocks
allowed_ssh_cidr  = null
```

## Features

- **AWS SSM Access**: Secure instance access without SSH keys
- **SSM Document Execution**: Automated server configuration via SSM (no user data)
- **Auto SSH Security (Optional)**: Security group restricts SSH to your current IP
- **2-Container Docker**: Flask app + official Nginx proxy
- **S3 Storage**: Encrypted app files with versioning
- **IAM Roles**: Minimal permissions for EC2 and SSM
- **File Change Detection**: Auto re-deploys when files change
- **Elastic IP**: Static public IP for consistent access

## Project Structure

```
chucknoris-jokes/
├── app/                        # Flask Application
│   ├── server.py
│   ├── templates/index.html
│   ├── static/style.css
│   └── requirements.txt
├── docker/                     # Container Config
│   ├── Dockerfile              # Flask app container
│   ├── nginx.conf              # Nginx proxy config
│   └── docker-compose.yml      # 2 containers
├── terraform/                   # IaC
│   ├── main.tf                 # AWS resources
│   ├── variables.tf            # Configuration
│   ├── outputs.tf              # Outputs
│   ├── ssm-document.yaml       # SSM Command document
│   └── terraform.tfvars        # Dev environment variables
├── scripts/                    # Automation (backup/reference)
│   └── setup.sh                # Legacy deployment script
├── .gitignore                  # Exclude secrets
├── README.md                   # This file
└── AGENTS.md                   # Detailed documentation
```

## Deployment Workflow

1. Developer modifies `app/` or `docker/` files
2. Runs `terraform apply`
3. Terraform detects file changes (SHA256 hash)
4. Files are zipped (via null_resource) and uploaded to S3
5. Terraform creates EC2 instance, SSM Document, and SSM Association
6. SSM Association triggers SSM Document on EC2 instance
7. SSM Document executes: downloads files, installs Docker, runs Docker Compose
8. Docker Compose builds and starts containers
9. Application accessible via Elastic IP
10. Instance access via AWS SSM (no SSH key required)

## Security Features

- **AWS SSM Access**: Secure instance access without SSH keys
- **Auto SSH Restriction (Optional)**: Security group can auto-detect deployer's public IP for SSH
- **S3 Encryption**: AES256 encryption at rest with versioning
- **IAM Least Privilege**: EC2 instance can only access specific S3 bucket
- **No Secrets in Git**: Sensitive values in `terraform.tfvars` are git-ignored

## Re-deploy on File Changes

```bash
# Modify app/ or docker/ files
cd terraform

# Terraform detects hash changes and re-deploys automatically
terraform apply -auto-approve
```

## Clean Up

```bash
cd terraform

# Destroy all resources
terraform destroy
```

## Troubleshooting

### Access EC2 via AWS SSM

```bash
# Install Session Manager plugin if not already installed
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Connect to instance
aws ssm start-session --target <INSTANCE-ID> --region ap-southeast-3
```

Or use the output from Terraform:

```bash
terraform output ssm_command
```

### Check Container Logs

```bash
aws ssm start-session --target <INSTANCE-ID> --region ap-southeast-3

# In the SSM session:
cd /opt/chucknoris-jokes/docker
docker-compose logs
```

### Force Re-deployment

```bash
cd terraform
# Taint the upload resource to force re-upload
terraform taint null_resource.upload_app_files
terraform apply
```

---

**License**: This project is for assessment purposes.
