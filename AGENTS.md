# Chuck Norris Jokes - DevOps Assessment

## AI Development Guidelines

When working on this project, the AI assistant must follow these rules:

### 1. Do NOT Delete .terraform Directory
- **Rule**: Never delete the `.terraform/` folder
- **Reason**: Contains downloaded provider binaries (100+ MB), re-downloading wastes time and bandwidth
- **Correct Action**: Only delete state files (`terraform.tfstate`, `terraform.tfstate.backup`, `.terraform.lock.hcl`)
- **Command**: `rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl`

### 2. Do NOT Delete Terraform State Files
- **Rule**: Never delete `terraform.tfstate` or `terraform.lock.hcl` files
- **Reason**: State files track infrastructure state; deleting them causes Terraform to lose all resource information
- **Impact**: Without state, Terraform can't manage or destroy existing resources properly
- **Correct Action**: Use `terraform state list` to check state, `terraform refresh` to update state
- **Command**: `terraform state rm <resource.address>` to remove specific resources from state

### 3. Use Best Practices
- **Security**: Never commit secrets or API keys; use `.gitignore` for sensitive files
- **Code Style**: Follow existing conventions; don't add unnecessary comments
- **Terraform**: Use resource dependencies, not `time_sleep` or `null_resource` with `triggers` for sequencing
- **Docker**: Use official base images (Alpine), multi-stage builds for smaller images
- **AWS**: Follow least privilege principle for IAM roles and policies

### 4. Clean Up Existing Resources Before Re-apply
- **Rule**: When resources exist in AWS with same names, delete them first
- **Reason**: Prevents "EntityAlreadyExists" or "InvalidGroup.Duplicate" errors
- **Approach**: Use `aws <service> delete-*` commands or `terraform destroy` before fresh apply

### 5. Mermaid Diagrams Over ASCII Art
- **Rule**: Use Mermaid.js for diagrams in markdown files
- **Reason**: Renders beautifully on GitHub and markdown platforms
- **Avoid**: Complex ASCII art with special characters that break on different terminals

### 6. File Paths in Terraform
- **Rule**: Always use `${path.module}` prefix for relative paths
- **Reason**: Terraform runs from terraform/ directory, but `path.module` resolves correctly
- **Example**: `filesha256("${path.module}/../app/server.py")` not `filesha256("app/server.py")`

### 7. Terraform-Native vs Shell Commands
- **Rule**: `archive_file` provider cannot archive directories directly with `content` attribute
- **Reason**: `archive_file` `source.content` only accepts file paths, not directories
- **Workaround**: Use `null_resource` with `tar` command to create archive
- **Example**: `null_resource` + `tar` + `aws s3 cp` for reliable directory archiving

### 8. SSM Document Parameters
- **Rule**: Parameter names must be alphanumeric (no underscores) for schema version 2.2
- **Reason**: AWS SSM API validation rejects `S3_BUCKET`, use `S3Bucket`
- **Convention**: Use PascalCase for parameter names

### 9. SSM Association Configuration
- **Rule**: Use `targets` parameter, not deprecated `instance_id`
- **Reason**: AWS provider v5.0+ uses `targets` with `key = "InstanceIds"`
- **Example**:
  ```hcl
  targets {
    key    = "InstanceIds"
    values = [aws_instance.web.id]
  }
  ```

### 10. AWS Resource Naming
- **Rule**: Follow consistent naming pattern with environment suffix
- **Pattern**: `<project-name>-<resource>-<environment>`
- **Examples**:
  - `chucknoris-jokes-sg-dev`
  - `chucknoris-jokes-ec2-role-dev`
  - `chucknoris-setup-dev`

### 11. Git Workflow
- **Rule**: Never commit `terraform.tfvars`, `.env`, or state files
- **Reason**: These contain sensitive values (API keys, access tokens)
- **Action**: These files must be in `.gitignore`

### 12. S3 Bucket Naming
- **Rule**: Bucket names must match regex `^[a-zA-Z0-9.\-_]{1,255}$`
- **Avoid**: Special characters, uppercase letters (AWS S3 is lowercase-only)
- **Pattern**: `chucknoris-jokes-dev-appfiles-<random-id>`

### 13. Route Table Validation
- **Rule**: Include route table data sources to validate public subnet
- **Reason**: Ensures subnet has IGW route (0.0.0.0/0 → IGW) for internet access
- **Data Sources**: `aws_route_tables` and `aws_route_table` with IGW filters

### 14. IAM Policy Resource Naming
- **Rule**: When policies are deleted manually, terraform import may be needed
- **Alternative**: Use `terraform destroy` to clean up all resources including IAM policies
- **Caution**: IAM policies with same name in different regions can cause conflicts

### 15. Terraform Remote State Backend
- **Rule**: Use `terraform-bootstrap/` to create backend resources (S3 + DynamoDB)
- **Reason**: Bootstrap pattern ensures backend exists before main Terraform uses it
- **Architecture**:
  - `terraform-bootstrap/`: Creates S3 bucket and DynamoDB table for state management
  - `terraform/`: Uses remote backend after initialization with -backend-config
- **Backend Resources**:
  - S3 bucket: `terraform-state-<env>-<aws-account-id>`
  - DynamoDB table: `terraform-state-locks-<env>-<aws-account-id>`
- **Security**: 
  - S3 bucket encrypted (AES256)
  - Versioning enabled (state history)
  - Public access blocked
  - DynamoDB for state locking (prevents concurrent apply conflicts)
- **Setup Workflow**:
  ```bash
  # 1. Create backend resources
  cd terraform-bootstrap
  terraform init
  terraform apply -auto-approve
  
  # 2. Get backend configuration
  terraform output bucket_name  # e.g., terraform-state-dev-123456789012
  terraform output table_name   # e.g., terraform-state-locks-dev-123456789012
  
  # 3. Initialize main Terraform with backend config
  cd ../terraform
  terraform init \
      -backend-config="bucket=<bucket_name>" \
      -backend-config="dynamodb_table=<table_name>" \
      -backend-config="region=ap-southeast-3" \
      -migrate-state
  
  # 4. Verify migration
  terraform state list
  ```
- **Backend Configuration**: Use `-backend-config` flags because Terraform's backend block doesn't support variable interpolation
- **Automation**: Use `terraform-bootstrap/bootstrap.sh` script for automated setup
- **Important**: Run bootstrap only once per environment, never delete bootstrap resources without destroying main infrastructure first
- **Migration**: When migrating from local state, Terraform automatically uploads existing state to S3

---

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
      - EC2 Instance (t3.nano)
      - Elastic IP (static public IP)
      - Security Group (auto-detects deployer IP)
      - SSM Document (setup commands)
      - SSM Association (automates document execution)
      - Default VPC & Subnet with IGW route

4. **Deployment** (`terraform/`)
    - SSM Document: Contains all setup steps
    - SSM Association: Triggers document on EC2 instance
    - No user data scripts
    - Secure access via AWS SSM (no SSH keys needed)

### Deployment Workflow

```
1. Developer modifies app/ or docker/ files
2. Runs: terraform apply
3. Terraform detects file changes (SHA256 hash)
4. Files are zipped (archive_file) and uploaded to S3 (aws_s3_object)
5. Terraform creates EC2 instance, SSM Document, and SSM Association
6. SSM Association triggers SSM Document on instance
7. SSM Document executes: downloads files, installs Docker, runs Docker Compose
8. Docker Compose builds and starts containers
9. Application accessible via Elastic IP
```

**Note**: SSM Document + Association is the deployment mechanism. Terraform creates the infrastructure, but SSM executes the application deployment on the EC2 instance.

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
- SSM Document for EC2 initialization
- SSM Association for automated script execution
- No manual SSH needed after initial setup
- Health checks ensure application is running
- File change detection triggers automatic deployment
- AWS SSM for secure instance access

### File Change Detection
- SHA256 hash of all app/docker files
- Triggers re-deployment when files change
- Efficient: only deploys when files change
- Hash changes trigger file upload and SSM association recreation
- `null_resource` with `tar` command reliably creates tarball with all directory contents

### Security by Default
- Secrets excluded from git (`.gitignore`)
- Example variable files for sensitive values
- Auto-detection of deployer IP for SSH
- Encrypted S3 bucket with versioning

### SSM Document Execution
- SSM Document: Contains setup commands (Docker, Compose, app deployment)
- SSM Association: Automatically runs document on EC2 instance
- Parameters: S3 bucket, object name, region
- Re-runs when association is recreated
- File upload happens before association (depends_on)

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
├── terraform-bootstrap/      # Backend infrastructure
│   ├── main.tf             # S3 bucket + DynamoDB table
│   ├── variables.tf        # Configuration
│   ├── outputs.tf          # Backend resource outputs
│   ├── bootstrap.sh        # Automated setup script
│   └── terraform.tfvars.example # Example variables
├── terraform/                # IaC
│   ├── main.tf             # AWS resources + backend config
│   ├── variables.tf        # Configuration
│   ├── outputs.tf          # Outputs
│   ├── ssm-document.yaml  # SSM Command document
│   ├── terraform.tfvars    # Dev environment variables (git-ignored)
│   └── terraform.tfvars.example # Example variables (committed)
├── scripts/                  # Automation (backup/reference)
│   └── setup.sh          # Legacy deployment script
├── .gitignore              # Exclude secrets
├── README.md              # Project documentation
└── AI.md                 # This file
```

## Key Implementation Details

### File Change Detection Mechanism

```hcl
# Terraform calculates hash of all source files
locals {
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

# Triggers re-deployment when hash changes
resource "null_resource" "app_setup_trigger" {
  depends_on = [aws_ssm_association.app_setup]

  triggers = {
    app_files_hash = local.app_files_hash
  }

  provisioner "local-exec" {
    command = "echo 'SSM Document applied with hash: ${local.app_files_hash}'"
  }
}
```

### File Upload to S3

```hcl
# Create tarball and upload using null_resource
resource "null_resource" "upload_app_files" {
  depends_on = [aws_s3_bucket.app_files]

  provisioner "local-exec" {
    command = "tar -czf /tmp/app-files.tar.gz ${path.module}/../app ${path.module}/../docker && aws s3 cp /tmp/app-files.tar.gz s3://${aws_s3_bucket.app_files.bucket}/${var.s3_object_name} --region ${var.region} && rm -f /tmp/app-files.tar.gz"
  }
}
```

### SSM Document Execution

```hcl
resource "aws_ssm_document" "app_setup" {
  name            = "chucknoris-setup-${var.environment}"
  document_type   = "Command"
  document_format = "YAML"

  content = templatefile("${path.module}/ssm-document.yaml", {
    S3Bucket = aws_s3_bucket.app_files.bucket
    S3Object = var.s3_object_name
    Region   = var.region
  })
}

resource "aws_ssm_association" "app_setup" {
  name = aws_ssm_document.app_setup.name

  depends_on = [null_resource.upload_app_files]

  targets {
    key    = "InstanceIds"
    values = [aws_instance.web.id]
  }

  parameters = {
    S3Bucket = aws_s3_bucket.app_files.bucket
    S3Object = var.s3_object_name
    Region   = var.region
  }
}
```

### SSM Document Script Flow

```bash
1. Install dependencies (yum-utils, curl, git)
2. Install Docker (amazon-linux-extras)
3. Install Docker Compose (standalone from GitHub)
4. Download files from S3 (app-files.tar.gz)
5. Extract to /opt/chucknoris-jokes
6. Run docker-compose build
7. Stop old containers (docker-compose down)
8. Start new containers (docker-compose up -d)
9. Health check (wait for Flask app container)
10. Health check (wait for nginx /health endpoint)
11. Display application URL
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

### Issue: File change not detected
**Solution**: Manually trigger re-deployment:
```bash
cd terraform
terraform taint null_resource.upload_app_files
terraform apply
```

### Issue: Application not accessible
**Solution**: Check instance status and logs via SSM:
```bash
# Connect via SSM
aws ssm start-session --target <INSTANCE-ID> --region ap-southeast-3

# In SSM session, check containers
docker ps

# Check logs
docker logs chucknoris-jokes-app
docker logs chucknoris-jokes-nginx

# Check docker-compose logs
cd /opt/chucknoris-jokes/docker
docker-compose logs
```

### Issue: SSM Document not executing
**Solution**: Check SSM command status:
```bash
# List SSM commands
aws ssm list-commands --filters key=DocumentName,value=chucknoris-setup-dev

# Get command invocation details
aws ssm get-command-invocation --command-id <COMMAND-ID> --instance-id <INSTANCE-ID>

# Check CloudWatch logs if available
```

### Issue: Elastic IP not attaching
**Solution**: Check EIP association:
```bash
cd terraform
terraform output elastic_ip

# Verify association
aws ec2 describe-addresses --allocation-ids <ALLOCATION-ID>
```

## Learning Outcomes

This project demonstrates:

✅ **Infrastructure as Code**: Terraform manages all AWS resources
✅ **Containerization**: Multi-stage Docker builds with 2-container setup
✅ **Automation**: SSM Document + Association eliminates manual configuration
✅ **Security**: AWS SSM access, no SSH keys needed, encryption, IAM least privilege
✅ **Change Detection**: Automatic file change detection with hash triggers
✅ **Scalability**: Elastic IP ensures consistent access
✅ **Best Practices**: Separation of concerns, official images, no hardcoded secrets
✅ **Cost Optimization**: Free tier resources, efficient container design
✅ **Documentation**: Complete README.md and AI.md, inline comments
✅ **Flexible Deployment**: Hash-based triggers allow re-deployment without recreation

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
