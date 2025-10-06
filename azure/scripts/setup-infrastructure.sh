#!/bin/bash

# Azure Infrastructure Setup Script for Nash PiSharp Application
# This script automates the deployment of Azure infrastructure using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
CONFIG_FILE="$PROJECT_ROOT/../shared/config.yaml"

# Default values
ENVIRONMENT="demo"
SUBSCRIPTION_ID=""
TENANT_ID=""
LOCATION="eastus"
PROJECT_NAME="nash-pisharp"

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "=================================="
    echo "  Azure Infrastructure Setup"
    echo "  Nash PiSharp Application"
    echo "=================================="
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  setup                 Setup complete infrastructure"
    echo "  destroy               Destroy infrastructure"
    echo "  plan                  Show Terraform plan"
    echo "  validate              Validate Terraform configuration"
    echo "  output                Show Terraform outputs"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (demo|dev|staging|prod) [default: demo]"
    echo "  -s, --subscription    Azure Subscription ID"
    echo "  -t, --tenant          Azure Tenant ID"
    echo "  -l, --location        Azure location [default: eastus]"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup -e demo -s <subscription-id> -t <tenant-id>"
    echo "  $0 plan -e prod"
    echo "  $0 destroy -e demo"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        echo "Installation guide: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        echo "Installation guide: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. It will be needed for AKS access."
        echo "Installation guide: https://kubernetes.io/docs/tasks/tools/"
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_warning "Helm is not installed. It will be needed for application deployment."
        echo "Installation guide: https://helm.sh/docs/intro/install/"
    fi
    
    print_success "Prerequisites check completed"
}

check_azure_login() {
    print_info "Checking Azure authentication..."
    
    if ! az account show &> /dev/null; then
        print_warning "Not logged into Azure. Please login first."
        az login
    fi
    
    # Set subscription if provided
    if [[ -n "$SUBSCRIPTION_ID" ]]; then
        print_info "Setting Azure subscription to: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    # Get current subscription info
    CURRENT_SUBSCRIPTION=$(az account show --query "id" -o tsv)
    CURRENT_TENANT=$(az account show --query "tenantId" -o tsv)
    
    print_info "Current Azure subscription: $CURRENT_SUBSCRIPTION"
    print_info "Current Azure tenant: $CURRENT_TENANT"
    
    # Update variables if not provided
    [[ -z "$SUBSCRIPTION_ID" ]] && SUBSCRIPTION_ID="$CURRENT_SUBSCRIPTION"
    [[ -z "$TENANT_ID" ]] && TENANT_ID="$CURRENT_TENANT"
}

setup_terraform_backend() {
    print_info "Setting up Terraform backend..."
    
    local backend_rg="${PROJECT_NAME}-${ENVIRONMENT}-tfstate-rg"
    local backend_sa="${PROJECT_NAME}${ENVIRONMENT}tfstate"
    local backend_container="tfstate"
    
    # Remove hyphens from storage account name (Azure requirement)
    backend_sa=$(echo "$backend_sa" | tr -d '-')
    
    print_info "Creating resource group for Terraform state: $backend_rg"
    az group create \
        --name "$backend_rg" \
        --location "$LOCATION" \
        --output table
    
    print_info "Creating storage account for Terraform state: $backend_sa"
    az storage account create \
        --resource-group "$backend_rg" \
        --name "$backend_sa" \
        --sku Standard_LRS \
        --encryption-services blob \
        --output table
    
    print_info "Creating storage container: $backend_container"
    az storage container create \
        --name "$backend_container" \
        --account-name "$backend_sa" \
        --output table
    
    # Get storage account key
    local storage_key=$(az storage account keys list \
        --resource-group "$backend_rg" \
        --account-name "$backend_sa" \
        --query "[0].value" -o tsv)
    
    # Create backend configuration
    cat > "$TERRAFORM_DIR/backend.tf" << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$backend_rg"
    storage_account_name = "$backend_sa"
    container_name       = "$backend_container"
    key                  = "${ENVIRONMENT}.terraform.tfstate"
  }
}
EOF
    
    print_success "Terraform backend configured"
}

create_terraform_vars() {
    print_info "Creating Terraform variables file..."
    
    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"
    
    cat > "$tfvars_file" << EOF
# Azure Configuration
subscription_id = "$SUBSCRIPTION_ID"
tenant_id      = "$TENANT_ID"
location       = "$LOCATION"

# Project Configuration
project_name = "$PROJECT_NAME"
environment  = "$ENVIRONMENT"

# Network Configuration
vnet_address_space     = ["10.0.0.0/16"]
subnet_address_prefix  = "10.0.1.0/24"
pod_subnet_prefix     = "10.0.2.0/24"

# AKS Configuration
aks_node_count    = 2
aks_node_vm_size  = "Standard_D2s_v3"
kubernetes_version = "1.28"

# Application Configuration
app_port = 3000
api_port = 5000

# Tags
tags = {
  Environment = "$ENVIRONMENT"
  Project     = "$PROJECT_NAME"
  ManagedBy   = "Terraform"
  CreatedBy   = "$(az account show --query user.name -o tsv)"
  CreatedDate = "$(date -u +%Y-%m-%d)"
}
EOF
    
    print_success "Terraform variables file created: $tfvars_file"
}

run_terraform() {
    local action="$1"
    
    print_info "Running Terraform $action..."
    
    cd "$TERRAFORM_DIR"
    
    case "$action" in
        "init")
            terraform init
            ;;
        "plan")
            terraform plan -var-file="terraform.tfvars"
            ;;
        "apply")
            terraform apply -var-file="terraform.tfvars" -auto-approve
            ;;
        "destroy")
            terraform destroy -var-file="terraform.tfvars" -auto-approve
            ;;
        "validate")
            terraform validate
            ;;
        "output")
            terraform output
            ;;
        *)
            print_error "Unknown Terraform action: $action"
            exit 1
            ;;
    esac
}

configure_kubectl() {
    print_info "Configuring kubectl for AKS cluster..."
    
    local aks_name="${PROJECT_NAME}-${ENVIRONMENT}-aks"
    local resource_group="${PROJECT_NAME}-${ENVIRONMENT}-rg"
    
    print_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group "$resource_group" \
        --name "$aks_name" \
        --overwrite-existing
    
    print_info "Testing kubectl connection..."
    kubectl get nodes
    
    print_success "kubectl configured successfully"
}

install_ingress_controller() {
    print_info "Installing NGINX Ingress Controller..."
    
    # Add NGINX ingress helm repo
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX ingress controller
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.loadBalancerSourceRanges="{0.0.0.0/0}" \
        --wait
    
    print_info "Waiting for Load Balancer IP..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    # Get external IP
    local external_ip=""
    local attempts=0
    while [[ -z "$external_ip" && $attempts -lt 30 ]]; do
        external_ip=$(kubectl get service ingress-nginx-controller \
            --namespace ingress-nginx \
            --output jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [[ -z "$external_ip" ]]; then
            print_info "Waiting for external IP... (attempt $((attempts + 1))/30)"
            sleep 10
            ((attempts++))
        fi
    done
    
    if [[ -n "$external_ip" ]]; then
        print_success "NGINX Ingress Controller installed with IP: $external_ip"
        echo "You can access the application at: http://$external_ip"
    else
        print_warning "External IP not assigned yet. Check with: kubectl get svc -n ingress-nginx"
    fi
}

setup_infrastructure() {
    print_info "Starting infrastructure setup..."
    
    # Setup Terraform backend
    setup_terraform_backend
    
    # Create Terraform variables
    create_terraform_vars
    
    # Run Terraform
    print_info "Initializing Terraform..."
    run_terraform "init"
    
    print_info "Validating Terraform configuration..."
    run_terraform "validate"
    
    print_info "Planning infrastructure changes..."
    run_terraform "plan"
    
    # Confirm before applying
    echo ""
    read -p "Do you want to apply these changes? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Infrastructure setup cancelled by user"
        exit 0
    fi
    
    print_info "Applying infrastructure changes..."
    run_terraform "apply"
    
    # Configure kubectl
    configure_kubectl
    
    # Install ingress controller
    install_ingress_controller
    
    # Show outputs
    print_info "Infrastructure outputs:"
    run_terraform "output"
    
    print_success "Infrastructure setup completed successfully!"
    
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Deploy the application: ./deploy.sh deploy -e $ENVIRONMENT"
    echo "2. Check the application status: kubectl get pods -n nash-pisharp"
    echo "3. Access the application using the external IP shown above"
}

destroy_infrastructure() {
    print_warning "This will destroy ALL infrastructure for environment: $ENVIRONMENT"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Infrastructure destruction cancelled by user"
        exit 0
    fi
    
    cd "$TERRAFORM_DIR"
    print_info "Destroying infrastructure..."
    run_terraform "destroy"
    
    print_success "Infrastructure destroyed successfully!"
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        setup|destroy|plan|validate|output)
            COMMAND="$1"
            shift
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -t|--tenant)
            TENANT_ID="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Main execution
print_banner

if [[ -z "$COMMAND" ]]; then
    print_error "No command specified"
    print_usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(demo|dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be one of: demo, dev, staging, prod"
    exit 1
fi

print_info "Environment: $ENVIRONMENT"
print_info "Location: $LOCATION"
print_info "Project: $PROJECT_NAME"

# Run checks
check_prerequisites
check_azure_login

# Execute command
case "$COMMAND" in
    "setup")
        setup_infrastructure
        ;;
    "destroy")
        destroy_infrastructure
        ;;
    "plan")
        cd "$TERRAFORM_DIR"
        create_terraform_vars
        run_terraform "init"
        run_terraform "plan"
        ;;
    "validate")
        cd "$TERRAFORM_DIR"
        run_terraform "validate"
        print_success "Terraform configuration is valid"
        ;;
    "output")
        cd "$TERRAFORM_DIR"
        run_terraform "output"
        ;;
esac

print_info "Script execution completed"