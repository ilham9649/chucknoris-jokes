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
    echo -e "${RED}"
    echo "========================================="
    echo "  Chuck Norris Jokes - Destroy Script"
    echo "========================================="
    echo -e "${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

confirm_destroy() {
    print_warning "This will destroy all AWS resources created by Terraform"
    print_warning "This action cannot be undone!"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Destroy cancelled"
        exit 0
    fi
}

destroy_infrastructure() {
    print_info "Destroying infrastructure..."
    cd "$TERRAFORM_DIR"
    
    if [ ! -f ".terraform/environment" ]; then
        print_info "Initializing Terraform first..."
        terraform init
    fi
    
    terraform destroy -var-file=environments/dev.tfvars
    
    rm -f /tmp/chucknoris_ec2_ip.txt
    
    print_success "Infrastructure destroyed successfully"
}

cleanup_local_files() {
    print_info "Cleaning up local files..."
    
    rm -f "$TERRAFORM_DIR/tfplan"
    rm -f "$TERRAFORM_DIR/terraform.tfstate"
    rm -f "$TERRAFORM_DIR/terraform.tfstate.backup"
    rm -f /tmp/chucknoris_ec2_ip.txt
    
    print_success "Local files cleaned up"
}

main() {
    print_banner
    
    if [ "$1" != "--force" ] && [ "$1" != "-f" ]; then
        confirm_destroy
    fi
    
    destroy_infrastructure
    cleanup_local_files
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  All resources destroyed successfully${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --force, -f    Skip confirmation prompt"
    echo ""
    exit 0
fi

main "$@"
