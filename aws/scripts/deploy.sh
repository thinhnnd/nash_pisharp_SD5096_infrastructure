#!/bin/bash

# AWS ECR Build and Deploy Script
# This script builds Docker images and deploys to AWS EKS

set -e  # Exit on any error

# Configuration
PROJECT_NAME="nash-pisharp"
ENVIRONMENT="demo"
AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="nash-pisharp-eks"

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
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

# Get AWS account ID
get_aws_account_id() {
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    log_info "ECR Registry: $ECR_REGISTRY"
}

# Login to ECR
ecr_login() {
    log_info "Logging into ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    log_success "Successfully logged into ECR"
}

# Build Docker images
build_images() {
    local build_tag=${1:-latest}
    
    log_info "Building Docker images with tag: $build_tag"
    
    # Check if application directories exist or clone them
    if [ ! -d "frontend" ]; then
        log_info "Frontend directory not found, cloning from repository..."
        git clone https://github.com/thinhnnd/nash_pisharp_SD5096_frontend.git frontend
    fi
    
    if [ ! -d "backend" ]; then
        log_info "Backend directory not found, cloning from repository..."
        git clone https://github.com/thinhnnd/nash_pisharp_SD5096_backend.git backend
    fi
    
    # Build frontend
    if [ -d "frontend" ]; then
        log_info "Building frontend image..."
        cd frontend
        docker build -t $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-frontend:$build_tag .
        docker tag $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-frontend:$build_tag $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-frontend:latest
        cd ..
        log_success "Frontend image built successfully"
    else
        log_error "Frontend directory not found and failed to clone"
        exit 1
    fi
    
    # Build backend
    if [ -d "backend" ]; then
        log_info "Building backend image..."
        cd backend
        docker build -t $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-backend:$build_tag .
        docker tag $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-backend:$build_tag $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-backend:latest
        cd ..
        log_success "Backend image built successfully"
    else
        log_error "Backend directory not found and failed to clone"
        exit 1
    fi
}

# Push images to ECR
push_images() {
    local build_tag=${1:-latest}
    
    log_info "Pushing images to ECR..."
    
    # Push frontend
    if docker images | grep -q "$PROJECT_NAME-$ENVIRONMENT-frontend"; then
        log_info "Pushing frontend image..."
        docker push $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-frontend:$build_tag
        docker push $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-frontend:latest
        log_success "Frontend image pushed successfully"
    fi
    
    # Push backend
    if docker images | grep -q "$PROJECT_NAME-$ENVIRONMENT-backend"; then
        log_info "Pushing backend image..."
        docker push $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-backend:$build_tag
        docker push $ECR_REGISTRY/$PROJECT_NAME-$ENVIRONMENT-backend:latest
        log_success "Backend image pushed successfully"
    fi
}

# Configure kubectl for EKS
configure_kubectl() {
    log_info "Configuring kubectl for EKS cluster: $EKS_CLUSTER_NAME"
    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        log_success "Successfully configured kubectl for EKS"
    else
        log_error "Failed to configure kubectl for EKS"
        exit 1
    fi
}

# Deploy using Helm
deploy_application() {
    local build_tag=${1:-latest}
    local values_file=${2:-values.yaml}
    
    log_info "Deploying application using Helm..."
    log_info "Using values file: $values_file"
    log_info "Image tag: $build_tag"
    
    # Navigate to charts directory
    if [ ! -d "aws/charts/nash-pisharp-app" ]; then
        log_error "Helm chart directory not found: aws/charts/nash-pisharp-app"
        exit 1
    fi
    
    cd aws/charts
    
    # Deploy with Helm
    helm upgrade --install $PROJECT_NAME-app ./nash-pisharp-app \
        --namespace $PROJECT_NAME-$ENVIRONMENT \
        --create-namespace \
        --set image.registry=$ECR_REGISTRY \
        --set frontend.image.tag=$build_tag \
        --set backend.image.tag=$build_tag \
        --set frontend.image.repository=$PROJECT_NAME-$ENVIRONMENT-frontend \
        --set backend.image.repository=$PROJECT_NAME-$ENVIRONMENT-backend \
        -f $values_file \
        --timeout 10m \
        --wait
    
    cd ../..
    
    log_success "Application deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check pod status
    log_info "Checking pod status..."
    kubectl get pods -n $PROJECT_NAME-$ENVIRONMENT
    
    # Wait for rollouts
    log_info "Waiting for rollouts to complete..."
    kubectl rollout status deployment/$PROJECT_NAME-app-frontend -n $PROJECT_NAME-$ENVIRONMENT --timeout=300s
    kubectl rollout status deployment/$PROJECT_NAME-app-backend -n $PROJECT_NAME-$ENVIRONMENT --timeout=300s
    kubectl rollout status deployment/$PROJECT_NAME-app-mongodb -n $PROJECT_NAME-$ENVIRONMENT --timeout=300s
    
    # Get services and ingress
    log_info "Services:"
    kubectl get services -n $PROJECT_NAME-$ENVIRONMENT
    
    log_info "Ingress:"
    kubectl get ingress -n $PROJECT_NAME-$ENVIRONMENT
    
    # Get ALB DNS name
    ALB_DNS=$(kubectl get ingress $PROJECT_NAME-app -n $PROJECT_NAME-$ENVIRONMENT -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ ! -z "$ALB_DNS" ]; then
        log_success "Application URL: http://$ALB_DNS"
    else
        log_warning "ALB DNS not ready yet. It may take a few minutes to provision."
    fi
    
    log_success "Deployment verification completed"
}

# Clean up local Docker images
cleanup() {
    log_info "Cleaning up local Docker images..."
    docker image prune -f
    docker system prune -f --volumes || true
    log_success "Cleanup completed"
}

# Main execution
main() {
    local command=${1:-deploy}
    local build_tag=${2:-$(date +%Y%m%d-%H%M%S)}
    local values_file=${3:-values.yaml}
    
    case $command in
        "build")
            check_prerequisites
            get_aws_account_id
            ecr_login
            build_images $build_tag
            ;;
        "push")
            check_prerequisites
            get_aws_account_id
            ecr_login
            push_images $build_tag
            ;;
        "build-push")
            check_prerequisites
            get_aws_account_id
            ecr_login
            build_images $build_tag
            push_images $build_tag
            cleanup
            ;;
        "deploy")
            check_prerequisites
            get_aws_account_id
            ecr_login
            build_images $build_tag
            push_images $build_tag
            configure_kubectl
            deploy_application $build_tag $values_file
            verify_deployment
            cleanup
            ;;
        "verify")
            configure_kubectl
            verify_deployment
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "Usage: $0 {build|push|build-push|deploy|verify|cleanup} [build_tag] [values_file]"
            echo ""
            echo "Commands:"
            echo "  build      - Build Docker images only"
            echo "  push       - Push Docker images to ECR only"
            echo "  build-push - Build and push Docker images (no deploy)"
            echo "  deploy     - Build, push, and deploy application (default)"
            echo "  verify     - Verify existing deployment"
            echo "  cleanup    - Clean up local Docker images"
            echo ""
            echo "Parameters:"
            echo "  build_tag    - Tag for Docker images (default: timestamp)"
            echo "  values_file  - Helm values file (default: values.yaml)"
            echo ""
            echo "Examples:"
            echo "  $0 build-push v1.0.0         # Build and push only"
            echo "  $0 deploy v1.0.0 values-prod.yaml  # Complete deployment"
            echo "  $0 build latest              # Build images only"
            echo "  $0 verify                    # Verify deployment status"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"