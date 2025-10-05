# 🚀 Nash PiSharp Azure Deployment Guide

## Prerequisites Status

✅ **kubectl** - Installed (v1.34.1)  
🔄 **Azure CLI** - Just installed (restart PowerShell required)  
🔄 **Terraform** - Just installed (restart PowerShell required)  
🔄 **Helm** - Just installed (restart PowerShell required)  

## IMPORTANT: Restart PowerShell First!

After installing the tools above, **close and reopen PowerShell** to refresh the PATH.

---

## Step-by-Step Deployment

### Step 1: Verify Tools Installation

```powershell
# After restarting PowerShell, verify all tools:
az version
terraform version
helm version
kubectl version --client
```

### Step 2: Login to Azure

```powershell
# Login to your Azure account
az login

# List your subscriptions
az account list --output table

# Set the subscription you want to use (if you have multiple)
az account set --subscription "Your-Subscription-Name-or-ID"
```

### Step 3: Create Terraform Backend (Bootstrap)

```powershell
# Navigate to your infrastructure project
cd azure/terraform

# Create Resource Group for Terraform state
az group create --name "rg-nash-pisharp-demo" --location "East US"

# Create Storage Account for Terraform state (name must be globally unique)
az storage account create `
    --name "sanashpisharptfstate$(Get-Random -Minimum 1000 -Maximum 9999)" `
    --resource-group "rg-nash-pisharp-demo" `
    --location "East US" `
    --sku "Standard_LRS"

# Get the storage account name you just created
$STORAGE_ACCOUNT = az storage account list --resource-group "rg-nash-pisharp-demo" --query "[0].name" --output tsv

# Create container for Terraform state
az storage container create `
    --name "tfstate" `
    --account-name $STORAGE_ACCOUNT

Write-Host "Storage Account Name: $STORAGE_ACCOUNT"
```

### Step 4: Configure Terraform Variables

```powershell
# Copy the example variables file
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
notepad terraform.tfvars
```

**Update terraform.tfvars with:**
```hcl
# General configuration
project_name    = "nash-pisharp"
environment     = "demo"
location        = "East US"
resource_group_name = "rg-nash-pisharp-demo"

# Network configuration
vnet_name       = "vnet-nash-pisharp"
vnet_cidr       = "10.0.0.0/16"
aks_subnet_cidr = "10.0.1.0/24"
vm_subnet_cidr  = "10.0.2.0/24"

# ACR configuration (name must be globally unique)
acr_name          = "acrnashpisharp$(Get-Random -Minimum 1000 -Maximum 9999)"
acr_sku           = "Standard"
acr_admin_enabled = true

# AKS configuration
cluster_name       = "aks-nash-pisharp"
dns_prefix         = "aks-nash-pisharp"
kubernetes_version = "1.27.3"
node_count         = 2
vm_size           = "Standard_D2s_v3"
```

### Step 5: Initialize and Deploy Infrastructure

```powershell
# Initialize Terraform with backend configuration
terraform init `
    -backend-config="resource_group_name=rg-nash-pisharp-demo" `
    -backend-config="storage_account_name=$STORAGE_ACCOUNT" `
    -backend-config="container_name=tfstate" `
    -backend-config="key=azure/terraform.tfstate"

# Plan the deployment
terraform plan

# Apply the changes (will take 10-15 minutes)
terraform apply -auto-approve
```

### Step 6: Configure kubectl

```powershell
# Get AKS credentials
az aks get-credentials --resource-group rg-nash-pisharp-demo --name aks-nash-pisharp

# Verify connection
kubectl get nodes
```

### Step 7: Install NGINX Ingress Controller

```powershell
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx `
    --namespace ingress-nginx `
    --create-namespace `
    --set controller.service.type=LoadBalancer

# Wait for external IP (takes 2-3 minutes)
kubectl get service ingress-nginx-controller --namespace ingress-nginx --watch
```

### Step 8: Get ACR Information

```powershell
# Get ACR login server
$ACR_SERVER = terraform output -raw acr_login_server
Write-Host "ACR Login Server: $ACR_SERVER"

# Login to ACR
az acr login --name $(terraform output -raw acr_name)
```

### Step 9: Build and Push Application Images

```powershell
# Navigate to your application source code
cd ../../kubernetes/src

# Build frontend image
cd frontend
docker build -t ${ACR_SERVER}/frontend:latest .
docker push ${ACR_SERVER}/frontend:latest

# Build backend image
cd ../backend
docker build -t ${ACR_SERVER}/backend:latest .
docker push ${ACR_SERVER}/backend:latest

# Return to charts directory
cd ../../nash_pisharp_SD5096_infrastructure/azure/charts
```

### Step 10: Deploy Application with Helm

```powershell
# Apply shared policies
kubectl apply -f ../../shared/policies.yaml

# Install the application
helm install nash-pisharp-app ./nash-pisharp-app `
    --namespace nash-pisharp-demo `
    --create-namespace `
    --set image.registry=$ACR_SERVER `
    --set frontend.image.tag=latest `
    --set backend.image.tag=latest
```

### Step 11: Verify Deployment

```powershell
# Check all pods are running
kubectl get pods -n nash-pisharp-demo

# Check services
kubectl get svc -n nash-pisharp-demo

# Get ingress external IP
kubectl get ingress -n nash-pisharp-demo

# Get external IP from ingress controller
$EXTERNAL_IP = kubectl get service ingress-nginx-controller --namespace ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Application URL: http://$EXTERNAL_IP"
```

---

## 🎉 Success!

Your Nash PiSharp application should now be running on Azure AKS!

Access your application at: `http://<EXTERNAL-IP>`

## 🧹 Cleanup (When Done)

```powershell
# Uninstall Helm releases
helm uninstall nash-pisharp-app -n nash-pisharp-demo
helm uninstall ingress-nginx -n ingress-nginx

# Delete namespaces
kubectl delete namespace nash-pisharp-demo
kubectl delete namespace ingress-nginx

# Destroy Terraform resources
terraform destroy -auto-approve

# Optional: Delete resource group
az group delete --name rg-nash-pisharp-demo --yes --no-wait
```

## 🔍 Troubleshooting

If you encounter issues, check:
1. Azure subscription permissions
2. Resource quotas in your region
3. ACR name uniqueness
4. Network connectivity

## 📞 Common Commands

```powershell
# View logs
kubectl logs -f deployment/nash-pisharp-app-frontend -n nash-pisharp-demo
kubectl logs -f deployment/nash-pisharp-app-backend -n nash-pisharp-demo
kubectl logs -f deployment/nash-pisharp-app-mongodb -n nash-pisharp-demo

# Debug pods
kubectl describe pod <pod-name> -n nash-pisharp-demo

# Port forward for testing
kubectl port-forward svc/nash-pisharp-app-frontend 3000:3000 -n nash-pisharp-demo
```
