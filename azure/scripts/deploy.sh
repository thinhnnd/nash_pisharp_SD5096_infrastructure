#!/bin/bash

# Azure Application Deployment Script for Nash PiSharp
# This script automates the deployment of applications to AKS using Helm

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
CHARTS_DIR="$PROJECT_ROOT/charts"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Default values
ENVIRONMENT="demo"
NAMESPACE="nash-pisharp"
RELEASE_NAME="nash-pisharp-app"
CHART_PATH="$CHARTS_DIR/nash-pisharp-app"
TIMEOUT="600s"
WAIT_FOR_DEPLOYMENT=true

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "=================================="
    echo "  Azure Application Deployment"
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
    echo "  deploy                Deploy application to AKS"
    echo "  upgrade               Upgrade existing deployment"
    echo "  rollback              Rollback to previous release"
    echo "  uninstall             Remove application from AKS"
    echo "  status                Show deployment status"
    echo "  logs                  Show application logs"
    echo "  port-forward          Setup port forwarding"
    echo "  build-push            Build and push Docker images to ACR"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (demo|dev|staging|prod) [default: demo]"
    echo "  -n, --namespace       Kubernetes namespace [default: nash-pisharp]"
    echo "  -r, --release         Helm release name [default: nash-pisharp-app]"
    echo "  -t, --timeout         Deployment timeout [default: 600s]"
    echo "  --no-wait             Don't wait for deployment to complete"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy -e demo"
    echo "  $0 upgrade -e prod"
    echo "  $0 status -e dev"
    echo "  $0 build-push -e staging"
    echo "  $0 logs -e demo"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install it first."
        exit 1
    fi
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed. It's needed for build-push command."
    fi
    
    print_success "Prerequisites check completed"
}

check_cluster_connection() {
    print_info "Checking cluster connection..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Please run: az aks get-credentials --resource-group <rg-name> --name <aks-name>"
        exit 1
    fi
    
    local cluster_name=$(kubectl config current-context)
    print_success "Connected to cluster: $cluster_name"
}

get_terraform_outputs() {
    print_info "Getting Terraform outputs..."
    
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Check if terraform state exists
    if ! terraform state list &> /dev/null; then
        print_error "Terraform state not found. Please run infrastructure setup first."
        exit 1
    fi
    
    # Get outputs
    ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server 2>/dev/null || echo "")
    AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    
    if [[ -z "$ACR_LOGIN_SERVER" ]]; then
        print_warning "ACR login server not found in Terraform outputs"
    else
        print_info "ACR Login Server: $ACR_LOGIN_SERVER"
    fi
    
    if [[ -z "$AKS_CLUSTER_NAME" ]]; then
        print_warning "AKS cluster name not found in Terraform outputs"
    else
        print_info "AKS Cluster: $AKS_CLUSTER_NAME"
    fi
}

create_namespace() {
    print_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_info "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace $NAMESPACE created"
    fi
}

build_and_push_images() {
    print_info "Building and pushing Docker images..."
    
    if [[ -z "$ACR_LOGIN_SERVER" ]]; then
        print_error "ACR login server not available. Cannot push images."
        exit 1
    fi
    
    # Login to ACR
    print_info "Logging into ACR..."
    az acr login --name "${ACR_LOGIN_SERVER%%.azurecr.io}"
    
    # Build tag for this deployment
    local build_tag="${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"
    
    # Frontend image
    print_info "Building frontend image..."
    local frontend_image="${ACR_LOGIN_SERVER}/nash-pisharp-frontend:${build_tag}"
    
    # Since we don't have the actual source code, we'll create a simple placeholder
    # In real scenario, you would build from the actual source repositories
    
    cat > /tmp/Dockerfile.frontend << 'EOF'
FROM nginx:alpine
COPY <<EOF /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><title>Nash PiSharp Frontend</title></head>
<body>
<h1>Nash PiSharp Frontend - ${ENVIRONMENT}</h1>
<p>Frontend application placeholder</p>
</body>
</html>
EOF
EOF
    
    docker build -t "$frontend_image" -f /tmp/Dockerfile.frontend /tmp/
    docker push "$frontend_image"
    print_success "Frontend image pushed: $frontend_image"
    
    # Backend image
    print_info "Building backend image..."
    local backend_image="${ACR_LOGIN_SERVER}/nash-pisharp-backend:${build_tag}"
    
    cat > /tmp/Dockerfile.backend << 'EOF'
FROM node:alpine
WORKDIR /app
COPY <<EOF package.json
{
  "name": "nash-pisharp-backend",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
COPY <<EOF server.js
const express = require('express');
const app = express();
const port = process.env.PORT || 5000;

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', environment: process.env.NODE_ENV || 'development' });
});

app.get('/api/status', (req, res) => {
  res.json({ 
    message: 'Nash PiSharp Backend API',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(\`Server running on port \${port}\`);
});
EOF
RUN npm install
EXPOSE 5000
CMD ["node", "server.js"]
EOF
    
    docker build -t "$backend_image" -f /tmp/Dockerfile.backend /tmp/
    docker push "$backend_image"
    print_success "Backend image pushed: $backend_image"
    
    # Clean up
    rm -f /tmp/Dockerfile.frontend /tmp/Dockerfile.backend
    
    # Save image tags for deployment
    echo "FRONTEND_IMAGE=$frontend_image" > /tmp/image-tags.env
    echo "BACKEND_IMAGE=$backend_image" >> /tmp/image-tags.env
    
    print_success "Images built and pushed successfully"
    print_info "Image tags saved to: /tmp/image-tags.env"
}

deploy_application() {
    print_info "Deploying application with Helm..."
    
    # Create namespace
    create_namespace
    
    # Prepare values file
    local values_file="$CHART_PATH/values-${ENVIRONMENT}.yaml"
    if [[ ! -f "$values_file" ]]; then
        print_warning "Environment-specific values file not found: $values_file"
        values_file="$CHART_PATH/values.yaml"
    fi
    
    # Load image tags if available
    local image_overrides=""
    if [[ -f "/tmp/image-tags.env" ]]; then
        source /tmp/image-tags.env
        if [[ -n "$FRONTEND_IMAGE" && -n "$BACKEND_IMAGE" ]]; then
            image_overrides="--set frontend.image.repository=${FRONTEND_IMAGE%:*} --set frontend.image.tag=${FRONTEND_IMAGE##*:} --set backend.image.repository=${BACKEND_IMAGE%:*} --set backend.image.tag=${BACKEND_IMAGE##*:}"
            print_info "Using custom image tags from build"
        fi
    fi
    
    # Helm install/upgrade
    local helm_args="--namespace $NAMESPACE --timeout $TIMEOUT"
    if [[ "$WAIT_FOR_DEPLOYMENT" == "true" ]]; then
        helm_args="$helm_args --wait"
    fi
    
    local helm_command="helm upgrade --install $RELEASE_NAME $CHART_PATH -f $values_file $helm_args $image_overrides"
    
    print_info "Running: $helm_command"
    eval "$helm_command"
    
    print_success "Application deployed successfully"
    
    # Show deployment status
    show_deployment_status
}

upgrade_application() {
    print_info "Upgrading application..."
    
    # Check if release exists
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        print_info "Use 'deploy' command to install the application first"
        exit 1
    fi
    
    deploy_application
}

rollback_application() {
    print_info "Rolling back application..."
    
    # Check if release exists
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        exit 1
    fi
    
    # Get revision to rollback to
    local revisions=$(helm history "$RELEASE_NAME" -n "$NAMESPACE" --max 5)
    echo "$revisions"
    
    read -p "Enter revision number to rollback to (or press Enter for previous): " revision
    
    local rollback_cmd="helm rollback $RELEASE_NAME"
    if [[ -n "$revision" ]]; then
        rollback_cmd="$rollback_cmd $revision"
    fi
    rollback_cmd="$rollback_cmd -n $NAMESPACE"
    
    print_info "Running: $rollback_cmd"
    eval "$rollback_cmd"
    
    print_success "Application rolled back successfully"
    show_deployment_status
}

uninstall_application() {
    print_warning "This will remove the application from the cluster"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled by user"
        exit 0
    fi
    
    print_info "Uninstalling application..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
    
    print_success "Application uninstalled successfully"
}

show_deployment_status() {
    print_info "Deployment Status:"
    echo ""
    
    # Helm release status
    print_info "Helm Release Status:"
    helm status "$RELEASE_NAME" -n "$NAMESPACE"
    echo ""
    
    # Pod status
    print_info "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
    echo ""
    
    # Service status
    print_info "Service Status:"
    kubectl get services -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
    echo ""
    
    # Ingress status
    print_info "Ingress Status:"
    kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" 2>/dev/null || echo "No ingress found"
    echo ""
    
    # Get external access information
    local external_ip=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$external_ip" ]]; then
        print_success "Application accessible at: http://$external_ip"
    else
        print_info "External IP not yet assigned. Check with: kubectl get svc -n ingress-nginx"
    fi
}

show_application_logs() {
    print_info "Application Logs:"
    
    # Get all pods
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$pods" ]]; then
        print_warning "No pods found for release: $RELEASE_NAME"
        exit 1
    fi
    
    for pod in $pods; do
        echo ""
        print_info "Logs for pod: $pod"
        echo "----------------------------------------"
        kubectl logs "$pod" -n "$NAMESPACE" --tail=50
    done
}

setup_port_forwarding() {
    print_info "Setting up port forwarding..."
    
    # Get frontend service
    local frontend_service=$(kubectl get service -n "$NAMESPACE" -l app.kubernetes.io/name=frontend,app.kubernetes.io/instance="$RELEASE_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    # Get backend service
    local backend_service=$(kubectl get service -n "$NAMESPACE" -l app.kubernetes.io/name=backend,app.kubernetes.io/instance="$RELEASE_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$frontend_service" ]]; then
        print_info "Port forwarding frontend service: $frontend_service"
        echo "Access frontend at: http://localhost:3000"
        kubectl port-forward service/"$frontend_service" 3000:80 -n "$NAMESPACE" &
    fi
    
    if [[ -n "$backend_service" ]]; then
        print_info "Port forwarding backend service: $backend_service"
        echo "Access backend at: http://localhost:5000"
        kubectl port-forward service/"$backend_service" 5000:5000 -n "$NAMESPACE" &
    fi
    
    print_info "Port forwarding setup completed"
    print_warning "Press Ctrl+C to stop port forwarding"
    wait
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        deploy|upgrade|rollback|uninstall|status|logs|port-forward|build-push)
            COMMAND="$1"
            shift
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --no-wait)
            WAIT_FOR_DEPLOYMENT=false
            shift
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
print_info "Namespace: $NAMESPACE"
print_info "Release: $RELEASE_NAME"

# Run checks (skip for some commands)
if [[ "$COMMAND" != "build-push" ]]; then
    check_prerequisites
    check_cluster_connection
fi

# Get Terraform outputs
get_terraform_outputs

# Execute command
case "$COMMAND" in
    "deploy")
        deploy_application
        ;;
    "upgrade")
        upgrade_application
        ;;
    "rollback")
        rollback_application
        ;;
    "uninstall")
        uninstall_application
        ;;
    "status")
        show_deployment_status
        ;;
    "logs")
        show_application_logs
        ;;
    "port-forward")
        setup_port_forwarding
        ;;
    "build-push")
        check_prerequisites
        build_and_push_images
        ;;
esac

print_info "Script execution completed"