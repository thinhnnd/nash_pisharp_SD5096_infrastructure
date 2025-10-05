# Nash```
nash_pisharp_SD5096_infrastructure/
├── azure/
│   ├── terraform/      # IaC for Azure (AKS, ACR, VNet)
│   │   ├── bootstrap/  # Foundation resources
│   │   ├── vnet/      # Vi# Navigate back to charts directory from application directories
cd ../../nash_pisharp_SD5096_infrastructure/azure/chartsal Network
│   │   ├── acr/       # Container Registry
│   │   ├── aks/       # Kubernetes cluster
│   └── charts/         # Helm charts for Azure deployment
│       └── nash-pisharp-app/
├── aws/
│   ├── terraform/      # IaC for AWS (EKS, S3, VPC) [Future]
│   └── charts/         # Helm charts for AWS deployment [Future]
├── shared/             # Common configurations, policies, secrets
└── README.md

apps/
├── nash_pisharp_SD5096_backend/  # Node.js/Express API server
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   ├── config/
│   ├── models/
│   └── routes/
└── nash_pisharp_SD5096_frontend/ # React.js application
    ├── Dockerfile
    ├── package.json
    ├── public/
    └── src/
```rastructure

This repository contains Infrastructure as Code (IaC) for deploying the Nash PiSharp demo application to cloud providers using Terraform and Helm.

## Repository Structure

```
nash_pisharp_SD5096_infrastructure/
├── azure/
│   ├── terraform/      # IaC for Azure (AKS, ACR, VNet)
│   │   ├── bootstrap/  # Foundation resources
│   │   ├── vnet/      # Virtual Network
│   │   ├── acr/       # Container Registry
│   │   ├── aks/       # Kubernetes cluster
│   │   └── vm/        # Virtual Machine (optional)
│   └── charts/         # Helm charts for Azure deployment
│       └── nash-pisharp-app/
├── aws/
│   ├── terraform/      # IaC for AWS (EKS, S3, VPC) [Future]
│   └── charts/         # Helm charts for AWS deployment [Future]
├── shared/             # Common configurations, policies, secrets
└── README.md
```

## Application Components

- **Frontend**: React.js application
- **Backend**: Node.js/Express API server  
- **Database**: MongoDB with persistent storage
- **Ingress**: NGINX Ingress Controller for routing

## Azure Deployment

### Prerequisites

1. **Azure CLI** installed and configured
2. **Terraform** (>= 1.0) installed
3. **Helm** (>= 3.0) installed
4. **kubectl** installed
5. Valid Azure subscription with appropriate permissions

### Step 1: Initial Setup (Bootstrap)

First, you need to create the backend storage for Terraform state:

```powershell
# Login to Azure
az login

# Create resource group for Terraform state
az group create --name "rg-nash-pisharp-demo" --location "East US"

# Create storage account for Terraform state
az storage account create `
    --name "sanashpisharptfstate" `
    --resource-group "rg-nash-pisharp-demo" `
    --location "East US" `
    --sku "Standard_LRS"

# Create container for Terraform state
az storage container create `
    --name "tfstate" `
    --account-name "sanashpisharptfstate"
```

### Step 2: Configure Terraform

1. Navigate to the Azure Terraform directory:
```powershell
cd azure/terraform
```

2. Copy the example variables file:
```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` with your specific values:
```hcl
project_name    = "nash-pisharp"
environment     = "demo"
location        = "East US"
# ... other variables
```

4. Initialize Terraform with backend configuration:
```powershell
terraform init `
    -backend-config="resource_group_name=rg-nash-pisharp-demo" `
    -backend-config="storage_account_name=sanashpisharptfstate" `
    -backend-config="container_name=tfstate" `
    -backend-config="key=azure/terraform.tfstate"
```

### Step 3: Deploy Infrastructure

1. Plan the deployment:
```powershell
terraform plan
```

2. Apply the changes:
```powershell
terraform apply
```

This will create:
- Virtual Network with subnets
- AKS cluster with 2 nodes
- Azure Container Registry
- Log Analytics workspace
- Network Security Groups

### Step 4: Configure kubectl

Get AKS credentials:
```powershell
az aks get-credentials --resource-group rg-nash-pisharp-demo --name aks-nash-pisharp
```

Verify connection:
```powershell
kubectl get nodes
```

### Step 5: Install NGINX Ingress Controller

```powershell
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx `
    --namespace ingress-nginx `
    --create-namespace `
    --set controller.service.type=LoadBalancer
```

### Step 6: Build and Push Docker Images

1. Build your application images:

```powershell
# Build frontend 
# Note: You have to clone frontend repo first
cd ./nash_pisharp_SD5096_frontend
docker build -t acrnashpisharp.azurecr.io/frontend:latest .

# Build backend  
# Note: You have to clone frontend repo first

cd ./nash_pisharp_SD5096_backend
docker build -t acrnashpisharp.azurecr.io/backend:latest .
```

2. Login to ACR and push images:
```powershell
# Get ACR credentials
az acr login --name acrnashpisharp

# Push images
docker push acrnashpisharp.azurecr.io/frontend:latest
docker push acrnashpisharp.azurecr.io/backend:latest
```

### Step 7: Deploy Application with Helm

1. Navigate to the charts directory:
```powershell
# Navigate to charts directory from application directories
cd ./azure/charts
```

2. Create namespace and apply shared policies:
```powershell
kubectl apply -f ../../shared/policies.yaml
```

3. Install the application (includes MongoDB):
```powershell
helm install nash-pisharp-app ./nash-pisharp-app `
    --namespace nash-pisharp-demo `
    --create-namespace `
    --set image.registry=acrnashpisharp.azurecr.io `
    --set frontend.image.tag=latest `
    --set backend.image.tag=latest
```

Note: The chart includes built-in MongoDB deployment, no external dependencies needed.

### Step 8: Verify Deployment

1. Check pods:
```powershell
kubectl get pods -n nash-pisharp-demo
```

2. Check services:
```powershell
kubectl get svc -n nash-pisharp-demo
```

3. Get ingress external IP:
```powershell
kubectl get ingress -n nash-pisharp-demo
```

4. Access the application:
```
http://<EXTERNAL-IP>
```

## Terraform Modules

### Bootstrap Module
- Creates resource group
- Sets up storage account for Terraform state
- Creates Key Vault for secrets

### VNet Module
- Creates Virtual Network and subnets
- Configures Network Security Groups
- Sets up network associations

### ACR Module
- Creates Azure Container Registry
- Configurable SKU (Basic, Standard, Premium)
- Supports geo-replication and network rules (Premium)
- Admin user configuration

### AKS Module  
- Deploys AKS cluster with configurable nodes
- Sets up Log Analytics workspace
- Configures RBAC and monitoring
- Role assignment for AKS to pull from ACR

## Helm Chart Features

- **Multi-component**: Separate deployments for frontend, backend, and MongoDB
- **Built-in MongoDB**: Self-contained MongoDB deployment with persistence
- **Configurable**: Extensive values.yaml for customization
- **Security**: Pod security contexts and network policies
- **Monitoring**: Ready for Prometheus integration
- **Autoscaling**: HPA configuration available
- **Environment-specific**: Dev and prod configurations available

## Customization

### Environment-specific Values

Create environment-specific values files:

```powershell
# Development
helm install nash-pisharp-app ./nash-pisharp-app -f values-dev.yaml

# Production  
helm install nash-pisharp-app ./nash-pisharp-app -f values-prod.yaml
```

### Monitoring and Observability

Enable monitoring by setting in values.yaml:
```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

## Cleanup

To destroy all resources:

```powershell
# Uninstall Helm releases
helm uninstall nash-pisharp-app -n nash-pisharp-demo
helm uninstall ingress-nginx -n ingress-nginx

# Delete namespaces
kubectl delete namespace nash-pisharp-demo
kubectl delete namespace ingress-nginx

# Destroy Terraform resources
terraform destroy

# Optional: Delete resource group
az group delete --name rg-nash-pisharp-demo
```

## Troubleshooting

### Common Issues

1. **Image pull errors**: Ensure ACR is properly configured and images are pushed
2. **Ingress not working**: Check NGINX controller is installed and LoadBalancer has external IP
3. **MongoDB connection issues**: Verify service names and environment variables
4. **Resource limits**: Check namespace quotas and node capacity

### Useful Commands

```powershell
# View logs
kubectl logs -f deployment/nash-pisharp-app-frontend -n nash-pisharp-demo
kubectl logs -f deployment/nash-pisharp-app-backend -n nash-pisharp-demo

# Debug pods
kubectl describe pod <pod-name> -n nash-pisharp-demo

# Port forward for testing
kubectl port-forward svc/nash-pisharp-app-frontend 3000:3000 -n nash-pisharp-demo
```

## Next Steps

- [ ] Add AWS infrastructure
- [ ] Implement GitOps with ArgoCD
- [ ] Add monitoring with Prometheus/Grafana
- [ ] Implement backup strategies
- [ ] Add CI/CD pipelines
