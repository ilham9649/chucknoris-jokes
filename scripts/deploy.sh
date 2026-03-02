#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    echo "========================================="
    echo "  Chuck Norris Jokes - Deployment Script"
    echo "========================================="
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found - local testing will not be available"
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install them before running this script"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

check_terraform_vars() {
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found!"
        print_info "Please copy terraform.tfvars.example to terraform.tfvars"
        print_info "and update with your AWS key pair name"
        echo ""
        echo "  cd terraform"
        echo "  cp terraform.tfvars.example terraform.tfvars"
        echo "  # Edit terraform.tfvars with your values"
        exit 1
    fi
    print_success "Terraform variables file found"
}

deploy_infrastructure() {
    print_info "Deploying infrastructure with Terraform..."
    cd "$TERRAFORM_DIR"
    
    print_info "Initializing Terraform..."
    terraform init
    
    print_info "Planning deployment..."
    terraform plan -var-file=environments/dev.tfvars -out=tfplan
    
    print_info "Applying infrastructure..."
    terraform apply tfplan
    
    print_success "Infrastructure deployed successfully"
    
    print_info "Getting EC2 public IP..."
    EC2_IP=$(terraform output -raw instance_public_ip)
    echo "EC2 Public IP: $EC2_IP"
    
    echo "$EC2_IP" > /tmp/chucknoris_ec2_ip.txt
    
    cd "$PROJECT_ROOT"
}

get_ec2_ip() {
    if [ -f /tmp/chucknoris_ec2_ip.txt ]; then
        cat /tmp/chucknoris_ec2_ip.txt
    else
        cd "$TERRAFORM_DIR"
        terraform output -raw instance_public_ip 2>/dev/null || echo "Not deployed yet"
        cd "$PROJECT_ROOT"
    fi
}

print_final_message() {
    EC2_IP=$(get_ec2_ip)
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Deployment Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "Application URL: ${BLUE}http://$EC2_IP${NC}"
    echo ""
    echo -e "SSH Command: ${YELLOW}ssh -i /path/to/your/key.pem ec2-user@$EC2_IP${NC}"
    echo ""
    echo -e "To destroy infrastructure: ${YELLOW}./scripts/destroy.sh${NC}"
    echo ""
}

main() {
    print_banner
    
    check_prerequisites
    check_terraform_vars
    
    deploy_infrastructure
    
    print_final_message
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    exit 0
fi

main "$@"
