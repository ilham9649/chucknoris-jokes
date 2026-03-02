# Chuck Norris Jokes - DevOps Assessment

A fully automated deployment pipeline demonstrating Infrastructure as Code (IaC) and configuration management best practices.

## Overview

This project displays random Chuck Norris jokes fetched from the [Chuck Norris API](https://api.chucknorris.io/) and demonstrates:

- **Terraform** - Infrastructure as Code (AWS EC2, Security Groups, S3, IAM)
- **Docker** - Containerization with 2 containers (Flask app + Nginx proxy)
- **User Data** - Automated server configuration (no Ansible needed)
- **S3** - Application file storage

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
│  │         EC2 (t2.micro) - Amazon Linux 2023          │       │
│  │  ┌──────────────────────────────────────────────────┐│       │
│  │  │  User Data Script                             ││       │
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
│  │  │                             │           ││       │
│  │  └─────────────────────────────┼───────────┘│       │
│  │                                │ HTTP      │          │
│  │                                ▼          │          │
│  │                    api.chucknorris.io          │          │
│  └───────────────────────────────────────────────┘          │
│                                                    │         │
│  ┌────────────────────────────────────────────────┐          │
│  │         S3 Bucket (App Files)                │          │
│  │         app-files.zip                       │          │
│  └────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS key pair name

# 2. Deploy
cd ..
./scripts/deploy.sh

# 3. Access application at http://<EC2-PUBLIC-IP>
```

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- Docker >= 20.10 (for local testing)
- Existing SSH key pair in AWS

## Configuration

Edit `terraform/terraform.tfvars`:

```hcl
region            = "ap-southeast-3"
instance_type     = "t2.micro"
key_name          = "your-aws-key-pair-name"
allowed_ssh_cidr  = null  # Auto-detects your public IP
```

## Features

- **Auto SSH Security**: Security group restricts SSH to your current IP
- **2-Container Docker**: Flask app + official Nginx proxy
- **S3 Storage**: Encrypted app files with versioning
- **User Data Deployment**: No Ansible needed
- **IAM Roles**: Minimal permissions for EC2

## Clean Up

```bash
./scripts/destroy.sh
```

## License

This project is for assessment purposes.
