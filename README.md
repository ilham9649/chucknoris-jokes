# Chuck Norris Jokes - DevOps Assessment

A fully automated deployment pipeline demonstrating Infrastructure as Code (IaC) and configuration management best practices using Python Flask, Docker, Terraform, and AWS.

## Overview

This project displays random Chuck Norris jokes fetched from the [Chuck Norris API](https://api.chucknorris.io/) and demonstrates:

- **Terraform** - Infrastructure as Code (AWS EC2, Security Groups, S3, IAM)
- **Docker** - Containerization with 2 containers (Flask app + Nginx proxy)
- **Remote-Exec Provisioners** - Automated server configuration
- **S3** - Application file storage
- **Auto SSH Security** - Security group auto-detects your public IP

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         YOUR LAPTOP                               │
│  ┌─────────────┐  ┌─────────────┐                          │
│  │  Terraform  │  │    Docker   │                          │
│  │  (Plan)     │  │   (Test)    │                          │
│  └──────┬──────┘  └─────────────┘                          │
│         │                                                      │
│         │ AWS API + Upload to S3                              │
│         │                                                      │
│         ▼                                                      │
└─────────┼───────────────────────────────────────────────────────────┘
          │
┌─────────┼───────────────────────────────────────────────────────────┐
│         ▼            AWS Cloud (ap-southeast-3)                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │         Security Group (SSH from your IP)                  │   │
│  └────────────────┬───────────────────────────────────────────┘   │
│                   │                                              │
│  ┌────────────────▼──────────────────────────────────────┐       │
│  │         EC2 (t2.micro) - Amazon Linux 2            │       │
│  │  ┌──────────────────────────────────────────────────┐│       │
│  │  │  Setup Script (remote-exec)                    ││       │
│  │  │  1. Install Docker                           ││       │
│  │  │  2. Download from S3                        ││       │
│  │  │  3. Run docker-compose                       ││       │
│  │  └──────────────────────────────────────────────────┘│       │
│  │  ┌──────────────────────────────────────────────────┐│       │
│  │  │  Docker Compose                             ││       │
│  │  │  ┌───────────┐       ┌──────────────┐   ││       │
│  │  │  │   Nginx   │◀──────│  Flask App   │   ││       │
│  │  │  │ (port 80) │       │  (port 5000) │   ││       │
│  │  │  │Official   │       │              │   ││       │
│  │  │  └───────────┘       └──────┬───────┘   ││       │
│  │  └─────────────────────────────┼───────────┘│       │
│  │                                │ HTTP      │          │
│  │                                ▼          │          │
│  │                    api.chucknorris.io          │          │
│  └───────────────────────────────────────────────┘          │
│                                                    │         │
│  ┌────────────────────────────────────────────────┐          │
│  │         S3 Bucket (App Files)                │          │
│  │         app-files.tar.gz                     │          │
│  └────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- Docker >= 20.10 (for local testing)
- Existing SSH key pair in AWS

### Deployment

```bash
# 1. Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS key pair name

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

Edit `terraform/terraform.tfvars`:

```hcl
region            = "ap-southeast-3"
instance_type     = "t3.nano"
key_name          = "your-aws-key-pair-name"
allowed_ssh_cidr  = null  # Auto-detects your public IP
```

## Features

- **Auto SSH Security**: Security group restricts SSH to your current IP
- **2-Container Docker**: Flask app + official Nginx proxy
- **S3 Storage**: Encrypted app files with versioning
- **Remote-Exec Deployment**: No Ansible needed
- **IAM Roles**: Minimal permissions for EC2
- **File Change Detection**: Auto re-deploys when files change
- **Elastic IP**: Static public IP for consistent access

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
│   └── terraform.tfvars    # Dev environment variables
├── scripts/                  # Automation
│   └── setup.sh          # Server deployment script
├── .gitignore              # Exclude secrets
├── .env.example            # Environment variables example
├── README.md               # This file
└── AI.md                   # Detailed documentation
```

## Deployment Workflow

1. Developer modifies `app/` or `docker/` files
2. Runs `terraform apply`
3. Terraform detects file changes (SHA256 hash)
4. Files are zipped and uploaded to S3
5. EC2 instance is created/recreated
6. Terraform uploads `scripts/setup.sh` via provisioner
7. Terraform executes `setup.sh` via remote-exec
8. Setup script downloads files from S3
9. Docker Compose builds and starts containers
10. Application accessible via Elastic IP

## Security Features

- **Auto SSH Restriction**: Security group automatically detects deployer's public IP
- **S3 Encryption**: AES256 encryption at rest with versioning
- **IAM Least Privilege**: EC2 instance can only access specific S3 bucket
- **No Secrets in Git**: Sensitive values in `.tfvars.example`, `.env.example`

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

### SSH into EC2

```bash
ssh -i /path/to/your/private-key.pem ec2-user@<ELASTIC-IP>
```

### Check Container Logs

```bash
ssh -i /path/to/your/private-key.pem ec2-user@<ELASTIC-IP>
cd /opt/chucknoris-jokes/docker
docker-compose logs
```

### Force Re-deployment

```bash
cd terraform
terraform taint null_resource.app_setup
terraform apply
```

## Technology Stack

| Technology | Purpose |
|------------|---------|
| Python 3.11 | Flask application |
| Flask 3.0 | Web framework |
| Docker | Containerization |
| Docker Compose | Multi-container orchestration |
| Nginx | Reverse proxy (official image) |
| Terraform 1.0+ | Infrastructure as Code |
| AWS S3 | File storage |
| AWS EC2 | Compute |
| AWS IAM | Security |

## Documentation

For detailed documentation, see [AI.md](AI.md) which includes:
- Complete architecture details
- Security best practices
- File change detection mechanism
- Provisioner flow
- Troubleshooting guide
- Future enhancements

---

**License**: This project is for assessment purposes.
