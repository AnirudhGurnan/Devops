#!/bin/bash

# MongoDB Atlas Terraform Deployment Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    if [ ! -f "terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Copy from terraform.tfvars.example"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Deploy infrastructure
deploy() {
    log_info "Starting MongoDB Atlas deployment..."
    
    check_prerequisites
    
    log_info "Initializing Terraform..."
    terraform init
    
    log_info "Validating configuration..."
    terraform validate
    
    log_info "Creating deployment plan..."
    terraform plan
    
    read -p "Do you want to apply this plan? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    log_info "Applying configuration..."
    terraform apply -auto-approve
    
    log_success "Deployment completed!"
    show_outputs
}

# Show outputs
show_outputs() {
    echo ""
    echo "=== MongoDB Atlas Cluster Information ==="
    echo "Cluster Name: $(terraform output -raw cluster_name)"
    echo "Cluster State: $(terraform output -raw cluster_state)"
    echo "MongoDB Version: $(terraform output -raw mongodb_version)"
    echo ""
    echo "=== Connection Information ==="
    echo "Connection URI: $(terraform output -raw mongo_uri_srv)"
    echo "Atlas Dashboard: $(terraform output -raw atlas_cluster_url)"
    echo ""
    log_success "Your MongoDB Atlas sharded cluster is ready!"
}

# Destroy infrastructure
destroy() {
    log_warning "This will destroy all MongoDB Atlas resources!"
    read -p "Are you sure? Type 'destroy' to confirm: " confirm
    
    if [ "$confirm" != "destroy" ]; then
        log_info "Destroy cancelled"
        exit 0
    fi
    
    log_info "Destroying infrastructure..."
    terraform destroy -auto-approve
    log_success "Infrastructure destroyed"
}

# Show help
show_help() {
    echo "MongoDB Atlas Terraform Deployment"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy MongoDB Atlas cluster"
    echo "  destroy   Destroy all resources"
    echo "  plan      Show deployment plan"
    echo "  outputs   Show deployment outputs"
    echo "  help      Show this help"
}

# Main
case ${1:-deploy} in
    deploy)
        deploy
        ;;
    destroy)
        destroy
        ;;
    plan)
        check_prerequisites
        terraform init
        terraform plan
        ;;
    outputs)
        show_outputs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac