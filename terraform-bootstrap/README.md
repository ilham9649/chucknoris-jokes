# Terraform Bootstrap

This directory contains Terraform configuration for setting up the remote backend (S3 + DynamoDB) for the main Terraform infrastructure.

## Purpose

Creates the necessary AWS resources to support Terraform remote state:
- S3 bucket for storing Terraform state files
- DynamoDB table for state locking (prevents concurrent apply conflicts)

## Resources Created

- **S3 Bucket**: `terraform-state-<env>-<aws-account-id>`
  - Encrypted (AES256)
  - Versioning enabled (90-day retention)
  - Public access blocked
  - Server-side logging enabled
  
- **DynamoDB Table**: `terraform-state-locks-<env>-<aws-account-id>`
  - Partition key: `LockID` (string)
  - Point-in-time recovery enabled
  - Pay-per-request billing mode

## Quick Start

### Using Bootstrap Script (Recommended)

```bash
./bootstrap.sh
```

The script will:
1. Create `terraform.tfvars` from example
2. Initialize and apply bootstrap resources
3. Generate `backend.tf` for main Terraform
4. Display migration instructions

### Manual Setup

```bash
# 1. Create terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed

# 2. Initialize and apply
terraform init
terraform apply

# 3. Get outputs
terraform output bucket_name
terraform output table_name

# 4. Initialize main Terraform with backend configuration
cd ../terraform

# If migrating existing local state:
terraform init \
    -backend-config="bucket=<bucket_name>" \
    -backend-config="dynamodb_table=<table_name>" \
    -backend-config="region=ap-southeast-3" \
    -migrate-state

# Or if no existing state:
terraform init \
    -backend-config="bucket=<bucket_name>" \
    -backend-config="dynamodb_table=<table_name>" \
    -backend-config="region=ap-southeast-3"

# Or use a backend-config file:
cat > backend-config.tfvars << EOF
bucket         = "<bucket_name>"
dynamodb_table = "<table_name>"
region         = "ap-southeast-3"
EOF

terraform init -backend-config=backend-config.tfvars
```

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `bucket_name` | S3 bucket name for state | `terraform-state-dev-123456789012` |
| `bucket_arn` | S3 bucket ARN | `arn:aws:s3:::terraform-state-dev-123456789012` |
| `dynamodb_table_name` | DynamoDB table name for locks | `terraform-state-locks-dev-123456789012` |
| `dynamodb_table_arn` | DynamoDB table ARN | `arn:aws:dynamodb:ap-southeast-3:123456789012:table/terraform-state-locks-dev-123456789012` |
| `aws_account_id` | AWS Account ID | `123456789012` |

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `region` | AWS region for backend resources | `ap-southeast-3` | No |
| `environment` | Environment name (dev, staging, prod) | `dev` | No |
| `enable_point_in_time_recovery` | Enable PITR for DynamoDB | `true` | No |

## State Migration

After creating backend resources, initialize main Terraform with backend configuration:

```bash
cd ../terraform

# Option 1: Using -backend-config flags
terraform init \
    -backend-config="bucket=terraform-state-dev-123456789012" \
    -backend-config="dynamodb_table=terraform-state-locks-dev-123456789012" \
    -backend-config="region=ap-southeast-3" \
    -migrate-state

# Option 2: Using backend-config file
cat > backend-config.tfvars << EOF
bucket         = "terraform-state-dev-123456789012"
dynamodb_table = "terraform-state-locks-dev-123456789012"
region         = "ap-southeast-3"
EOF

terraform init -backend-config=backend-config.tfvars -migrate-state

# Verify migration
terraform state list
```

**Note**: Backend configuration is passed via `-backend-config` flags because Terraform's backend block doesn't support variable interpolation.

## Cleanup

**Important**: Always destroy main infrastructure before removing backend resources!

```bash
# 1. Destroy main infrastructure
cd ../terraform
terraform destroy

# 2. (Optional) Remove backend configuration to revert to local state
rm backend-config.tfvars
# Reinitialize with local backend:
terraform init -migrate-state -reconfigure

# 3. Destroy backend resources
cd ../terraform-bootstrap
terraform destroy
```

## Backend Configuration Notes

Terraform backend configuration uses `-backend-config` flags because:
- Backend blocks cannot use variables (configuration must be complete before init)
- Allows flexible configuration without modifying code
- Supports multiple environments with different configs
- Can use backend-config files for reusability

### Reinitializing Backend

To change backend configuration (different bucket/table):

```bash
terraform init -backend-config=backend-config.tfvars -reconfigure
```

## Security

- S3 bucket blocks all public access
- Server-side encryption enabled (AES256)
- Versioning preserves state history
- Lifecycle rule cleans up old versions after 90 days
- DynamoDB table uses AWS managed encryption at rest

## Naming Convention

Resources include AWS Account ID to ensure global uniqueness:
- S3 bucket: `terraform-state-<env>-<aws-account-id>`
- DynamoDB table: `terraform-state-locks-<env>-<aws-account-id>`

This prevents conflicts when multiple environments or accounts use similar naming patterns.
