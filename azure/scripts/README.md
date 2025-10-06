# Azure Infrastructure and Deployment Scripts

This directory contains automation scripts for setting up and managing Azure infrastructure for the Nash PiSharp application.

## 📁 Script Overview

### 🐧 Linux/macOS Scripts (Bash)
- **`setup-infrastructure.sh`** - Complete infrastructure setup and management
- **`deploy.sh`** - Application deployment and management

### 🪟 Windows Scripts (PowerShell)
- **`setup-infrastructure.ps1`** - Infrastructure setup for Windows
- **`deploy.ps1`** - Application deployment for Windows

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:

```bash
# Required tools
az --version          # Azure CLI
terraform --version   # Terraform
kubectl version       # Kubernetes CLI
helm version          # Helm package manager
docker --version      # Docker (for image builds)
```

### Installation Guides

- **Azure CLI**: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- **Terraform**: https://learn.hashicorp.com/tutorials/terraform/install-cli
- **kubectl**: https://kubernetes.io/docs/tasks/tools/
- **Helm**: https://helm.sh/docs/intro/install/
- **Docker**: https://docs.docker.com/get-docker/

## 🏗️ Infrastructure Setup

### Linux/macOS (Bash)

```bash
# Make scripts executable
chmod +x *.sh

# Setup complete infrastructure
./setup-infrastructure.sh setup -e demo -s <subscription-id> -t <tenant-id>

# Other commands
./setup-infrastructure.sh plan -e demo        # Show plan
./setup-infrastructure.sh validate           # Validate config
./setup-infrastructure.sh output -e demo     # Show outputs
./setup-infrastructure.sh destroy -e demo    # Destroy infrastructure
```

### Windows (PowerShell)

```powershell
# Setup complete infrastructure
.\setup-infrastructure.ps1 Setup -Environment demo -SubscriptionId <subscription-id> -TenantId <tenant-id>

# Other commands
.\setup-infrastructure.ps1 Plan -Environment demo        # Show plan
.\setup-infrastructure.ps1 Validate                     # Validate config
.\setup-infrastructure.ps1 Output -Environment demo     # Show outputs
.\setup-infrastructure.ps1 Destroy -Environment demo    # Destroy infrastructure
```

## 📦 Application Deployment

### Linux/macOS (Bash)

```bash
# Build and push images to ACR
./deploy.sh build-push -e demo

# Deploy application
./deploy.sh deploy -e demo

# Other commands
./deploy.sh upgrade -e demo       # Upgrade deployment
./deploy.sh status -e demo        # Show status
./deploy.sh logs -e demo          # Show logs
./deploy.sh port-forward -e demo  # Port forwarding
./deploy.sh rollback -e demo      # Rollback deployment
./deploy.sh uninstall -e demo     # Remove application
```

### Windows (PowerShell)

```powershell
# Build and push images to ACR
.\deploy.ps1 BuildPush -Environment demo

# Deploy application
.\deploy.ps1 Deploy -Environment demo

# Other commands
.\deploy.ps1 Upgrade -Environment demo       # Upgrade deployment
.\deploy.ps1 Status -Environment demo        # Show status
.\deploy.ps1 Logs -Environment demo          # Show logs
.\deploy.ps1 PortForward -Environment demo   # Port forwarding
.\deploy.ps1 Rollback -Environment demo      # Rollback deployment
.\deploy.ps1 Uninstall -Environment demo     # Remove application
```

## 🌍 Environment Support

All scripts support multiple environments:

- **demo**: Development/testing environment
- **dev**: Development environment
- **staging**: Staging environment
- **prod**: Production environment

## 📋 Script Parameters

### Infrastructure Setup Parameters

| Parameter | Bash | PowerShell | Description | Default |
|-----------|------|------------|-------------|---------|
| Environment | `-e, --environment` | `-Environment` | Target environment | demo |
| Subscription ID | `-s, --subscription` | `-SubscriptionId` | Azure subscription ID | Current |
| Tenant ID | `-t, --tenant` | `-TenantId` | Azure tenant ID | Current |
| Location | `-l, --location` | `-Location` | Azure region | eastus |

### Deployment Parameters

| Parameter | Bash | PowerShell | Description | Default |
|-----------|------|------------|-------------|---------|
| Environment | `-e, --environment` | `-Environment` | Target environment | demo |
| Namespace | `-n, --namespace` | `-Namespace` | Kubernetes namespace | nash-pisharp |
| Release Name | `-r, --release` | `-ReleaseName` | Helm release name | nash-pisharp-app |
| Timeout | `-t, --timeout` | `-Timeout` | Deployment timeout | 600s |
| No Wait | `--no-wait` | `-NoWait` | Don't wait for deployment | false |

## 🔄 Complete Workflow

### 1. Infrastructure Setup

```bash
# Linux/macOS
./setup-infrastructure.sh setup -e demo -s <subscription-id>

# Windows
.\setup-infrastructure.ps1 Setup -Environment demo -SubscriptionId <subscription-id>
```

This will:
- ✅ Create Terraform backend (storage account)
- ✅ Generate Terraform variables
- ✅ Deploy AKS, ACR, networking, and security
- ✅ Configure kubectl
- ✅ Install NGINX Ingress Controller
- ✅ Display access information

### 2. Application Deployment

```bash
# Linux/macOS
./deploy.sh build-push -e demo    # Build and push images
./deploy.sh deploy -e demo        # Deploy to AKS

# Windows
.\deploy.ps1 BuildPush -Environment demo    # Build and push images
.\deploy.ps1 Deploy -Environment demo       # Deploy to AKS
```

This will:
- ✅ Build Docker images
- ✅ Push to Azure Container Registry
- ✅ Deploy with Helm
- ✅ Configure ingress
- ✅ Show application status

### 3. Access Application

After deployment, the scripts will show:
- External IP address for access
- Application URLs
- Status information

## 🔧 Troubleshooting

### Common Issues

#### 1. Azure Authentication
```bash
# If authentication fails
az login
az account set --subscription <subscription-id>
```

#### 2. Terraform Backend Issues
```bash
# If backend setup fails, check storage account
az storage account list --output table
```

#### 3. kubectl Connection
```bash
# If kubectl fails to connect
az aks get-credentials --resource-group <rg-name> --name <aks-name>
```

#### 4. Docker Build Failures
```bash
# Check Docker daemon
docker info

# Login to ACR
az acr login --name <acr-name>
```

### Debug Commands

```bash
# Check infrastructure status
./setup-infrastructure.sh output -e demo

# Check application status
./deploy.sh status -e demo

# View application logs
./deploy.sh logs -e demo

# Test local access
./deploy.sh port-forward -e demo
```

## 📊 Resource Monitoring

### Infrastructure Resources

The scripts create these Azure resources:

- **Resource Group**: `nash-pisharp-<env>-rg`
- **AKS Cluster**: `nash-pisharp-<env>-aks`
- **Container Registry**: `nashpisharp<env>acr`
- **Virtual Network**: `nash-pisharp-<env>-vnet`
- **Network Security Groups**: Various NSGs
- **Storage Account**: For Terraform state

### Application Resources

- **Kubernetes Namespace**: `nash-pisharp`
- **Helm Release**: `nash-pisharp-app`
- **Services**: Frontend, Backend, MongoDB
- **Ingress**: NGINX-based ingress
- **Persistent Volumes**: For MongoDB data

## 🧹 Cleanup

### Remove Application Only

```bash
# Linux/macOS
./deploy.sh uninstall -e demo

# Windows
.\deploy.ps1 Uninstall -Environment demo
```

### Remove Complete Infrastructure

```bash
# Linux/macOS
./setup-infrastructure.sh destroy -e demo

# Windows
.\setup-infrastructure.ps1 Destroy -Environment demo
```

⚠️ **Warning**: This will permanently delete all resources for the environment.

## 📚 Additional Resources

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🤝 Support

For issues with the scripts:

1. Check the troubleshooting section above
2. Review the logs for error messages
3. Ensure all prerequisites are installed
4. Verify Azure permissions and subscription access
5. Create an issue in the project repository

---

## 📝 Script Features

### ✨ Infrastructure Script Features

- **🔐 Automatic Azure Authentication**: Checks and handles Azure login
- **📦 Terraform Backend Setup**: Creates storage account for remote state
- **🎯 Environment-Specific Configuration**: Supports multiple environments
- **🔍 Validation and Planning**: Terraform validation and planning before apply
- **⚙️ AKS Configuration**: Automatic kubectl configuration
- **🌐 Ingress Setup**: NGINX Ingress Controller installation
- **📊 Output Display**: Shows important resource information
- **🛡️ Safety Checks**: Confirmation prompts for destructive operations

### ✨ Deployment Script Features

- **🐳 Docker Image Building**: Builds and pushes container images
- **📈 Helm Deployment**: Advanced Helm-based application deployment
- **🔄 Upgrade Support**: Seamless application upgrades
- **⏪ Rollback Capability**: Easy rollback to previous versions
- **📊 Status Monitoring**: Comprehensive deployment status
- **📝 Log Viewing**: Application log aggregation
- **🔗 Port Forwarding**: Local development access
- **🗑️ Clean Uninstall**: Complete application removal

### 🎨 User Experience Features

- **🌈 Colored Output**: Easy-to-read colored console output
- **📋 Progress Tracking**: Clear progress indicators
- **❗ Error Handling**: Comprehensive error handling and reporting
- **💡 Help Documentation**: Built-in help and usage information
- **🔧 Flexible Configuration**: Extensive parameter customization
- **⚡ Cross-Platform**: Both Bash and PowerShell versions

Choose the script version that matches your operating system and enjoy automated Azure infrastructure and application management! 🚀