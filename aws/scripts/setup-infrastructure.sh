#!/bin/bash

# AWS Infrastructure Setup Script
# This script sets up the complete AWS infrastructure for Nash PiSharp application

set -e

# Configuration
PROJECT_NAME="nash-pisharp"
ENVIRONMENT="demo"
AWS_REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

# Create S3 bucket for Terraform state
create_terraform_backend() {
    local bucket_name="$PROJECT_NAME-$ENVIRONMENT-terraform-state-$(openssl rand -hex 4)"
    local dynamodb_table="$PROJECT_NAME-$ENVIRONMENT-terraform-lock"
    
    log_info "Creating Terraform backend..."
    log_info "S3 Bucket: $bucket_name"
    log_info "DynamoDB Table: $dynamodb_table"
    
    # Create S3 bucket
    if aws s3 ls "s3://$bucket_name" 2>&1 | grep -q 'NoSuchBucket'; then
        aws s3 mb "s3://$bucket_name" --region $AWS_REGION
        log_success "S3 bucket created: $bucket_name"
    else
        log_warning "S3 bucket already exists: $bucket_name"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $bucket_name \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket $bucket_name \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket $bucket_name \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    # Create DynamoDB table for state locking
    if ! aws dynamodb describe-table --table-name $dynamodb_table --region $AWS_REGION &> /dev/null; then
        aws dynamodb create-table \
            --table-name $dynamodb_table \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region $AWS_REGION
        
        # Wait for table to be active
        aws dynamodb wait table-exists --table-name $dynamodb_table --region $AWS_REGION
        log_success "DynamoDB table created: $dynamodb_table"
    else
        log_warning "DynamoDB table already exists: $dynamodb_table"
    fi
    
    # Output backend configuration
    cat > backend-config.txt << EOF
bucket         = "$bucket_name"
key            = "aws/terraform.tfstate"
region         = "$AWS_REGION"
dynamodb_table = "$dynamodb_table"
encrypt        = true
EOF
    
    log_success "Terraform backend configuration saved to backend-config.txt"
    
    # Export for later use
    export TF_BACKEND_BUCKET="$bucket_name"
    export TF_BACKEND_DYNAMODB_TABLE="$dynamodb_table"
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    
    cd aws/terraform
    
    # Initialize with backend configuration
    if [ -f "../../backend-config.txt" ]; then
        terraform init -backend-config="../../backend-config.txt"
    else
        log_error "Backend configuration file not found"
        exit 1
    fi
    
    cd ../..
    
    log_success "Terraform initialized successfully"
}

# Create terraform.tfvars if it doesn't exist
create_terraform_vars() {
    local tfvars_file="aws/terraform/terraform.tfvars"
    
    if [ ! -f "$tfvars_file" ]; then
        log_info "Creating terraform.tfvars file..."
        
        # Copy from example
        cp aws/terraform/terraform.tfvars.example $tfvars_file
        
        log_warning "Please edit $tfvars_file with your specific values before running terraform apply"
        log_warning "Especially update the jenkins_existing_key_pair_name if you have an existing key pair"
        
        # Show the file content for review
        echo ""
        echo "Current terraform.tfvars content:"
        cat $tfvars_file
        echo ""
        
        read -p "Do you want to edit terraform.tfvars now? (y/n): " edit_vars
        if [ "$edit_vars" = "y" ] || [ "$edit_vars" = "Y" ]; then
            ${EDITOR:-nano} $tfvars_file
        fi
    else
        log_info "terraform.tfvars already exists"
    fi
}

# Plan Terraform deployment
plan_terraform() {
    log_info "Planning Terraform deployment..."
    
    cd aws/terraform
    terraform plan -out=tfplan
    cd ../..
    
    log_success "Terraform plan completed. Review the plan above."
}

# Apply Terraform deployment
apply_terraform() {
    log_info "Applying Terraform deployment..."
    
    cd aws/terraform
    
    if [ -f "tfplan" ]; then
        terraform apply tfplan
    else
        log_warning "No terraform plan found. Running apply without plan..."
        terraform apply -auto-approve
    fi
    
    cd ../..
    
    log_success "Terraform deployment completed"
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    log_info "Installing AWS Load Balancer Controller..."
    
    # Get cluster name from terraform output
    cd aws/terraform
    local cluster_name=$(terraform output -raw cluster_name)
    local region=$(terraform output -raw aws_region)
    local alb_role_arn=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
    cd ../..
    
    # Configure kubectl
    aws eks update-kubeconfig --region $region --name $cluster_name
    
    # Add Helm repository
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Install AWS Load Balancer Controller
    if [ ! -z "$alb_role_arn" ]; then
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=$cluster_name \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller \
            --set region=$region \
            --set vpcId=$(cd aws/terraform && terraform output -raw vpc_id) || true
    else
        log_warning "ALB controller role ARN not found, installing without service account annotation"
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=$cluster_name \
            --set region=$region \
            --set vpcId=$(cd aws/terraform && terraform output -raw vpc_id) || true
    fi
    
    log_success "AWS Load Balancer Controller installation initiated"
}

# Show deployment information
show_deployment_info() {
    log_info "Gathering deployment information..."
    
    cd aws/terraform
    
    echo ""
    echo "================================="
    echo "🎉 AWS Infrastructure Deployed! 🎉"
    echo "================================="
    echo ""
    
    echo "📊 Infrastructure Details:"
    echo "------------------------"
    echo "AWS Region: $(terraform output -raw aws_region)"
    echo "VPC ID: $(terraform output -raw vpc_id)"
    echo "EKS Cluster: $(terraform output -raw cluster_name)"
    echo "ECR Frontend: $(terraform output -raw ecr_frontend_repository_url)"
    echo "ECR Backend: $(terraform output -raw ecr_backend_repository_url)"
    echo ""
    
    echo "🖥️  Jenkins Server:"
    echo "------------------"
    echo "Instance ID: $(terraform output -raw jenkins_instance_id)"
    echo "Public IP: $(terraform output -raw jenkins_public_ip)"
    echo "Jenkins URL: $(terraform output -raw jenkins_url)"
    echo "SSH Command: $(terraform output -raw jenkins_ssh_command)"
    if terraform output jenkins_eip &> /dev/null; then
        echo "Elastic IP: $(terraform output -raw jenkins_eip)"
    fi
    echo ""
    
    echo "⚙️  Configuration Commands:"
    echo "--------------------------"
    echo "Configure kubectl:"
    echo "  $(terraform output -raw kubectl_config_command)"
    echo ""
    echo "Login to ECR:"
    echo "  $(terraform output -raw ecr_login_command)"
    echo ""
    
    echo "📋 Next Steps:"
    echo "-------------"
    echo "1. SSH to Jenkins server and get initial admin password:"
    echo "   ssh -i <your-key>.pem ubuntu@$(terraform output -raw jenkins_public_ip)"
    echo "   sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
    echo ""
    echo "2. Access Jenkins at: $(terraform output -raw jenkins_url)"
    echo ""
    echo "3. Configure kubectl locally:"
    echo "   $(terraform output -raw kubectl_config_command)"
    echo ""
    echo "4. Deploy application using Jenkins pipeline or:"
    echo "   cd ../../ && ./aws/scripts/deploy.sh"
    echo ""
    echo "5. Monitor ALB provisioning:"
    echo "   kubectl get ingress -n $PROJECT_NAME-$ENVIRONMENT -w"
    echo ""
    
    cd ../..
}

# Destroy infrastructure
destroy_infrastructure() {
    log_warning "This will destroy all AWS infrastructure!"
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" = "yes" ]; then
        log_info "Destroying infrastructure..."
        
        cd aws/terraform
        terraform destroy -auto-approve
        cd ../..
        
        log_success "Infrastructure destroyed"
    else
        log_info "Destroy cancelled"
    fi
}

# Main execution
main() {
    local command=${1:-setup}
    
    case $command in
        "setup")
            check_prerequisites
            create_terraform_backend
            init_terraform
            create_terraform_vars
            plan_terraform
            
            read -p "Do you want to apply the Terraform plan? (y/n): " apply_plan
            if [ "$apply_plan" = "y" ] || [ "$apply_plan" = "Y" ]; then
                apply_terraform
                install_alb_controller
                show_deployment_info
            else
                log_info "Terraform plan created but not applied. Run 'terraform apply' to deploy."
            fi
            ;;
        "apply")
            cd aws/terraform
            apply_terraform
            cd ../..
            install_alb_controller
            show_deployment_info
            ;;
        "plan")
            cd aws/terraform
            plan_terraform
            cd ../..
            ;;
        "info")
            show_deployment_info
            ;;
        "destroy")
            destroy_infrastructure
            ;;
        "backend")
            create_terraform_backend
            ;;
        *)
            echo "Usage: $0 {setup|apply|plan|info|destroy|backend}"
            echo ""
            echo "Commands:"
            echo "  setup    - Complete infrastructure setup (default)"
            echo "  apply    - Apply Terraform configuration"
            echo "  plan     - Plan Terraform deployment"
            echo "  info     - Show deployment information"
            echo "  destroy  - Destroy all infrastructure"
            echo "  backend  - Create Terraform backend only"
            echo ""
            echo "Examples:"
            echo "  $0 setup    # Complete setup"
            echo "  $0 plan     # Plan only"
            echo "  $0 destroy  # Destroy everything"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"