# PowerShell Script for Azure Infrastructure Setup
# This script provides PowerShell equivalents for Azure infrastructure management

# Colors for output
$ErrorActionPreference = "Stop"

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    switch ($Color) {
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

function Write-Info {
    param([string]$Message)
    Write-ColoredOutput "[INFO] $Message" "Blue"
}

function Write-Success {
    param([string]$Message)
    Write-ColoredOutput "[SUCCESS] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColoredOutput "[WARNING] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColoredOutput "[ERROR] $Message" "Red"
}

function Show-Banner {
    Write-ColoredOutput @"
==================================
  Azure Infrastructure Setup
  Nash PiSharp Application
  PowerShell Version
==================================
"@ "Blue"
}

function Show-Usage {
    Write-Host @"
Usage: .\setup-infrastructure.ps1 [COMMAND] [OPTIONS]

Commands:
  Setup                 Setup complete infrastructure
  Destroy               Destroy infrastructure
  Plan                  Show Terraform plan
  Validate              Validate Terraform configuration
  Output                Show Terraform outputs

Parameters:
  -Environment          Environment (demo|dev|staging|prod) [default: demo]
  -SubscriptionId       Azure Subscription ID
  -TenantId             Azure Tenant ID
  -Location             Azure location [default: eastus]
  -Help                 Show this help message

Examples:
  .\setup-infrastructure.ps1 Setup -Environment demo -SubscriptionId <subscription-id>
  .\setup-infrastructure.ps1 Plan -Environment prod
  .\setup-infrastructure.ps1 Destroy -Environment demo
"@
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Azure CLI
    try {
        $null = Get-Command az -ErrorAction Stop
        Write-Success "Azure CLI found"
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install it first."
        Write-Host "Installation guide: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
    
    # Check Terraform
    try {
        $null = Get-Command terraform -ErrorAction Stop
        Write-Success "Terraform found"
    }
    catch {
        Write-Error "Terraform is not installed. Please install it first."
        Write-Host "Installation guide: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    }
    
    # Check kubectl
    try {
        $null = Get-Command kubectl -ErrorAction Stop
        Write-Success "kubectl found"
    }
    catch {
        Write-Warning "kubectl is not installed. It will be needed for AKS access."
        Write-Host "Installation guide: https://kubernetes.io/docs/tasks/tools/"
    }
    
    # Check helm
    try {
        $null = Get-Command helm -ErrorAction Stop
        Write-Success "Helm found"
    }
    catch {
        Write-Warning "Helm is not installed. It will be needed for application deployment."
        Write-Host "Installation guide: https://helm.sh/docs/intro/install/"
    }
    
    Write-Success "Prerequisites check completed"
}

function Test-AzureLogin {
    param(
        [string]$SubscriptionId,
        [string]$TenantId
    )
    
    Write-Info "Checking Azure authentication..."
    
    try {
        $account = az account show --output json | ConvertFrom-Json
    }
    catch {
        Write-Warning "Not logged into Azure. Please login first."
        az login
        $account = az account show --output json | ConvertFrom-Json
    }
    
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-Info "Setting Azure subscription to: $SubscriptionId"
        az account set --subscription $SubscriptionId
        $account = az account show --output json | ConvertFrom-Json
    }
    
    Write-Info "Current Azure subscription: $($account.id)"
    Write-Info "Current Azure tenant: $($account.tenantId)"
    
    return @{
        SubscriptionId = $account.id
        TenantId = $account.tenantId
    }
}

function New-TerraformBackend {
    param(
        [string]$ProjectName,
        [string]$Environment,
        [string]$Location
    )
    
    Write-Info "Setting up Terraform backend..."
    
    $backendRg = "$ProjectName-$Environment-tfstate-rg"
    $backendSa = "$ProjectName$Environment" + "tfstate" -replace '-', ''
    $backendContainer = "tfstate"
    
    Write-Info "Creating resource group for Terraform state: $backendRg"
    az group create --name $backendRg --location $Location --output table
    
    Write-Info "Creating storage account for Terraform state: $backendSa"
    az storage account create `
        --resource-group $backendRg `
        --name $backendSa `
        --sku Standard_LRS `
        --encryption-services blob `
        --output table
    
    Write-Info "Creating storage container: $backendContainer"
    az storage container create `
        --name $backendContainer `
        --account-name $backendSa `
        --output table
    
    # Create backend configuration
    $backendConfig = @"
terraform {
  backend "azurerm" {
    resource_group_name  = "$backendRg"
    storage_account_name = "$backendSa"
    container_name       = "$backendContainer"
    key                  = "$Environment.terraform.tfstate"
  }
}
"@
    
    $backendConfig | Out-File -FilePath "$PSScriptRoot\..\terraform\backend.tf" -Encoding UTF8
    
    Write-Success "Terraform backend configured"
}

function New-TerraformVars {
    param(
        [string]$SubscriptionId,
        [string]$TenantId,
        [string]$Location,
        [string]$ProjectName,
        [string]$Environment
    )
    
    Write-Info "Creating Terraform variables file..."
    
    $userName = az account show --query user.name --output tsv
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    
    $tfvarsContent = @"
# Azure Configuration
subscription_id = "$SubscriptionId"
tenant_id      = "$TenantId"
location       = "$Location"

# Project Configuration
project_name = "$ProjectName"
environment  = "$Environment"

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
  Environment = "$Environment"
  Project     = "$ProjectName"
  ManagedBy   = "Terraform"
  CreatedBy   = "$userName"
  CreatedDate = "$currentDate"
}
"@
    
    $tfvarsFile = "$PSScriptRoot\..\terraform\terraform.tfvars"
    $tfvarsContent | Out-File -FilePath $tfvarsFile -Encoding UTF8
    
    Write-Success "Terraform variables file created: $tfvarsFile"
}

function Invoke-Terraform {
    param(
        [string]$Action,
        [string]$TerraformDir
    )
    
    Write-Info "Running Terraform $Action..."
    
    Push-Location $TerraformDir
    
    try {
        switch ($Action) {
            "init" {
                terraform init
            }
            "plan" {
                terraform plan -var-file="terraform.tfvars"
            }
            "apply" {
                terraform apply -var-file="terraform.tfvars" -auto-approve
            }
            "destroy" {
                terraform destroy -var-file="terraform.tfvars" -auto-approve
            }
            "validate" {
                terraform validate
            }
            "output" {
                terraform output
            }
            default {
                Write-Error "Unknown Terraform action: $Action"
                exit 1
            }
        }
    }
    finally {
        Pop-Location
    }
}

function Set-KubectlConfig {
    param(
        [string]$ProjectName,
        [string]$Environment
    )
    
    Write-Info "Configuring kubectl for AKS cluster..."
    
    $aksName = "$ProjectName-$Environment-aks"
    $resourceGroup = "$ProjectName-$Environment-rg"
    
    Write-Info "Getting AKS credentials..."
    az aks get-credentials `
        --resource-group $resourceGroup `
        --name $aksName `
        --overwrite-existing
    
    Write-Info "Testing kubectl connection..."
    kubectl get nodes
    
    Write-Success "kubectl configured successfully"
}

function Install-IngressController {
    Write-Info "Installing NGINX Ingress Controller..."
    
    # Add NGINX ingress helm repo
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX ingress controller
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
        --namespace ingress-nginx `
        --create-namespace `
        --set controller.service.type=LoadBalancer `
        --set controller.service.loadBalancerSourceRanges="{0.0.0.0/0}" `
        --wait
    
    Write-Info "Waiting for Load Balancer IP..."
    kubectl wait --namespace ingress-nginx `
        --for=condition=ready pod `
        --selector=app.kubernetes.io/component=controller `
        --timeout=120s
    
    # Get external IP
    $attempts = 0
    $maxAttempts = 30
    
    do {
        $externalIp = kubectl get service ingress-nginx-controller `
            --namespace ingress-nginx `
            --output jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        
        if (-not $externalIp) {
            Write-Info "Waiting for external IP... (attempt $($attempts + 1)/$maxAttempts)"
            Start-Sleep -Seconds 10
            $attempts++
        }
    } while (-not $externalIp -and $attempts -lt $maxAttempts)
    
    if ($externalIp) {
        Write-Success "NGINX Ingress Controller installed with IP: $externalIp"
        Write-Host "You can access the application at: http://$externalIp"
    }
    else {
        Write-Warning "External IP not assigned yet. Check with: kubectl get svc -n ingress-nginx"
    }
}

function Start-InfrastructureSetup {
    param(
        [string]$SubscriptionId,
        [string]$TenantId,
        [string]$Location,
        [string]$ProjectName,
        [string]$Environment
    )
    
    Write-Info "Starting infrastructure setup..."
    
    $terraformDir = "$PSScriptRoot\..\terraform"
    
    # Setup Terraform backend
    New-TerraformBackend -ProjectName $ProjectName -Environment $Environment -Location $Location
    
    # Create Terraform variables
    New-TerraformVars -SubscriptionId $SubscriptionId -TenantId $TenantId -Location $Location -ProjectName $ProjectName -Environment $Environment
    
    # Run Terraform
    Write-Info "Initializing Terraform..."
    Invoke-Terraform -Action "init" -TerraformDir $terraformDir
    
    Write-Info "Validating Terraform configuration..."
    Invoke-Terraform -Action "validate" -TerraformDir $terraformDir
    
    Write-Info "Planning infrastructure changes..."
    Invoke-Terraform -Action "plan" -TerraformDir $terraformDir
    
    # Confirm before applying
    Write-Host ""
    $confirmation = Read-Host "Do you want to apply these changes? (y/N)"
    if ($confirmation -notmatch '^[Yy]$') {
        Write-Warning "Infrastructure setup cancelled by user"
        exit 0
    }
    
    Write-Info "Applying infrastructure changes..."
    Invoke-Terraform -Action "apply" -TerraformDir $terraformDir
    
    # Configure kubectl
    Set-KubectlConfig -ProjectName $ProjectName -Environment $Environment
    
    # Install ingress controller
    Install-IngressController
    
    # Show outputs
    Write-Info "Infrastructure outputs:"
    Invoke-Terraform -Action "output" -TerraformDir $terraformDir
    
    Write-Success "Infrastructure setup completed successfully!"
    
    Write-Host ""
    Write-ColoredOutput "Next steps:" "Green"
    Write-Host "1. Deploy the application: .\deploy.ps1 Deploy -Environment $Environment"
    Write-Host "2. Check the application status: kubectl get pods -n nash-pisharp"
    Write-Host "3. Access the application using the external IP shown above"
}

function Remove-Infrastructure {
    param(
        [string]$Environment
    )
    
    Write-Warning "This will destroy ALL infrastructure for environment: $Environment"
    Write-Host ""
    $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
    if ($confirmation -notmatch '^[Yy]$') {
        Write-Info "Infrastructure destruction cancelled by user"
        exit 0
    }
    
    $terraformDir = "$PSScriptRoot\..\terraform"
    Write-Info "Destroying infrastructure..."
    Invoke-Terraform -Action "destroy" -TerraformDir $terraformDir
    
    Write-Success "Infrastructure destroyed successfully!"
}

# Main script parameters
param(
    [Parameter(Position=0)]
    [ValidateSet("Setup", "Destroy", "Plan", "Validate", "Output", "Help")]
    [string]$Command,
    
    [ValidateSet("demo", "dev", "staging", "prod")]
    [string]$Environment = "demo",
    
    [string]$SubscriptionId,
    
    [string]$TenantId,
    
    [string]$Location = "eastus",
    
    [switch]$Help
)

# Configuration
$ProjectName = "nash-pisharp"

# Main execution
if ($Help -or -not $Command) {
    Show-Usage
    exit 0
}

Show-Banner

Write-Info "Environment: $Environment"
Write-Info "Location: $Location"
Write-Info "Project: $ProjectName"

# Run checks
Test-Prerequisites
$azureInfo = Test-AzureLogin -SubscriptionId $SubscriptionId -TenantId $TenantId

# Update variables with actual values
if (-not $SubscriptionId) { $SubscriptionId = $azureInfo.SubscriptionId }
if (-not $TenantId) { $TenantId = $azureInfo.TenantId }

# Execute command
switch ($Command) {
    "Setup" {
        Start-InfrastructureSetup -SubscriptionId $SubscriptionId -TenantId $TenantId -Location $Location -ProjectName $ProjectName -Environment $Environment
    }
    "Destroy" {
        Remove-Infrastructure -Environment $Environment
    }
    "Plan" {
        $terraformDir = "$PSScriptRoot\..\terraform"
        New-TerraformVars -SubscriptionId $SubscriptionId -TenantId $TenantId -Location $Location -ProjectName $ProjectName -Environment $Environment
        Invoke-Terraform -Action "init" -TerraformDir $terraformDir
        Invoke-Terraform -Action "plan" -TerraformDir $terraformDir
    }
    "Validate" {
        $terraformDir = "$PSScriptRoot\..\terraform"
        Invoke-Terraform -Action "validate" -TerraformDir $terraformDir
        Write-Success "Terraform configuration is valid"
    }
    "Output" {
        $terraformDir = "$PSScriptRoot\..\terraform"
        Invoke-Terraform -Action "output" -TerraformDir $terraformDir
    }
}

Write-Info "Script execution completed"