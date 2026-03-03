#!/bin/bash

# Terraform Bootstrap Script
# This script helps set up the Terraform backend (S3 + DynamoDB) and migrate state

set -e

echo "=========================================="
echo "Terraform Bootstrap Setup"
echo "=========================================="
echo ""

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Error: terraform is not installed"
    exit 1
fi

# Check if aws CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: aws CLI is not installed"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "main.tf" ]; then
    echo "Error: Please run this script from the terraform-bootstrap directory"
    exit 1
fi

echo "Step 1: Creating terraform.tfvars from example..."
if [ ! -f "terraform.tfvars" ]; then
    cp terraform.tfvars.example terraform.tfvars
    echo "Created terraform.tfvars. Please review and update if needed."
else
    echo "terraform.tfvars already exists. Skipping..."
fi

echo ""
echo "Step 2: Initializing Terraform..."
terraform init

echo ""
echo "Step 3: Planning infrastructure changes..."
read -p "Do you want to review the plan? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform plan
else
    terraform plan -out=tfplan
fi

echo ""
echo "Step 4: Applying infrastructure..."
terraform apply

echo ""
echo "=========================================="
echo "Backend Setup Complete!"
echo "=========================================="
echo ""

# Get outputs
BUCKET_NAME=$(terraform output -raw bucket_name)
TABLE_NAME=$(terraform output -raw dynamodb_table_name)
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)

echo "Backend Resources Created:"
echo "  - S3 Bucket: $BUCKET_NAME"
echo "  - DynamoDB Table: $TABLE_NAME"
echo "  - AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Check if main terraform directory exists
if [ -d "../terraform" ]; then
    echo "Step 5: Configuring backend for main Terraform..."
    cd ../terraform

    # Check if terraform.tfstate exists (local state to migrate)
    if [ -f "terraform.tfstate" ]; then
        echo "Step 6: Migrating existing state to backend..."
        terraform init \
            -backend-config="bucket=$BUCKET_NAME" \
            -backend-config="dynamodb_table=$TABLE_NAME" \
            -backend-config="region=ap-southeast-3" \
            -migrate-state
    else
        echo "Step 6: Initializing with backend configuration..."
        terraform init \
            -backend-config="bucket=$BUCKET_NAME" \
            -backend-config="dynamodb_table=$TABLE_NAME" \
            -backend-config="region=ap-southeast-3"
    fi

    echo ""
    echo "Backend configured successfully!"
    echo ""
    echo "Configuration used:"
    echo "  bucket: $BUCKET_NAME"
    echo "  dynamodb_table: $TABLE_NAME"
    echo "  region: ap-southeast-3"
    echo ""

    # Create a backend-config file for reference
    cat > backend-config.tfvars << EOF
# Backend configuration file
# Use this file with: terraform init -backend-config=backend-config.tfvars

bucket         = "$BUCKET_NAME"
dynamodb_table = "$TABLE_NAME"
region         = "ap-southeast-3"
EOF

    echo "Created backend-config.tfvars for reference"
    echo ""
    echo "To reinitialize backend in the future:"
    echo "  terraform init -backend-config=backend-config.tfvars"
    echo ""
    echo "After initialization, verify state:"
    echo "  terraform state list"
    echo ""
else
    echo "Warning: terraform/ directory not found in parent directory"
    echo "Please initialize main Terraform with backend configuration:"
    echo "  terraform init \\"
    echo "    -backend-config=\"bucket=$BUCKET_NAME\" \\"
    echo "    -backend-config=\"dynamodb_table=$TABLE_NAME\" \\"
    echo "    -backend-config=\"region=ap-southeast-3\""
    echo ""
fi

echo "=========================================="
echo "Bootstrap Complete!"
echo "=========================================="
