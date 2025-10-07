# PowerShell Script for Azure Application Deployment
# This script focuses ONLY on deployment - no image building

# Main script parameters
param(
    [Parameter(Position=0)]
    [ValidateSet("Deploy", "Upgrade", "Rollback", "Uninstall", "Status", "Logs", "PortForward", "Help")]
    [string]$Command,
    
    [ValidateSet("demo", "dev", "staging", "prod")]
    [string]$Environment = "demo",
    
    [string]$Namespace = "default",
    
    [string]$ReleaseName = "nash-pisharp-app",
    
    [string]$Timeout = "600s",
    
    [switch]$NoWait,
    
    [switch]$Help
)

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
  Azure Application Deployment
  Nash PiSharp Application
  PowerShell Version
==================================
"@ "Blue"
}

function Show-Usage {
    Write-Host @"
Usage: .\deploy.ps1 [COMMAND] [OPTIONS]

Commands:
  Deploy                Deploy application to AKS
  Upgrade               Upgrade existing deployment
  Rollback              Rollback to previous release
  Uninstall             Remove application from AKS
  Status                Show deployment status
  Logs                  Show application logs
  PortForward          Setup port forwarding

Parameters:
  -Environment          Environment (demo|dev|staging|prod) [default: demo]
  -Namespace            Kubernetes namespace [default: nash-pisharp]
  -ReleaseName          Helm release name [default: nash-pisharp-app]
  -Timeout              Deployment timeout [default: 600s]
  -NoWait               Don't wait for deployment to complete
  -Help                 Show this help message

Examples:
  .\deploy.ps1 Deploy -Environment demo
  .\deploy.ps1 Upgrade -Environment prod
  .\deploy.ps1 Status -Environment dev
  .\deploy.ps1 Logs -Environment demo

Note: Images should be built and pushed to ACR separately before deployment.
      Update image tags in values-{environment}.yaml files as needed.
"@
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check kubectl
    try {
        $null = Get-Command kubectl -ErrorAction Stop
        Write-Success "kubectl found"
    }
    catch {
        Write-Error "kubectl is not installed. Please install it first."
        exit 1
    }
    
    # Check helm
    try {
        $null = Get-Command helm -ErrorAction Stop
        Write-Success "Helm found"
    }
    catch {
        Write-Error "Helm is not installed. Please install it first."
        exit 1
    }
    
    # Check Azure CLI
    try {
        $null = Get-Command az -ErrorAction Stop
        Write-Success "Azure CLI found"
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install it first."
        exit 1
    }
    
    Write-Success "Prerequisites check completed"
}

function Test-ClusterConnection {
    Write-Info "Checking cluster connection..."
    
    try {
        kubectl cluster-info | Out-Null
        $clusterName = kubectl config current-context
        Write-Success "Connected to cluster: $clusterName"
    }
    catch {
        Write-Error "Cannot connect to Kubernetes cluster"
        Write-Info "Please run: az aks get-credentials --resource-group <rg-name> --name <aks-name>"
        exit 1
    }
}

function New-Namespace {
    param([string]$Namespace)
    
    Write-Info "Creating namespace: $Namespace"
    
    $existingNamespace = kubectl get namespace $Namespace 2>$null
    if ($existingNamespace) {
        Write-Info "Namespace $Namespace already exists"
    }
    else {
        kubectl create namespace $Namespace
        Write-Success "Namespace $Namespace created"
    }
}

function Deploy-Application {
    param(
        [string]$Environment,
        [string]$Namespace,
        [string]$ReleaseName,
        [string]$Timeout,
        [bool]$WaitForDeployment
    )
    
    Write-Info "Deploying application with Helm..."
    
    # Create namespace
    New-Namespace -Namespace $Namespace
    
    # Prepare values file
    $chartsDir = "$PSScriptRoot\..\charts"
    $valuesFile = "$chartsDir\nash-pisharp-app\values-$Environment.yaml"
    if (-not (Test-Path $valuesFile)) {
        Write-Warning "Environment-specific values file not found: $valuesFile"
        $valuesFile = "$chartsDir\nash-pisharp-app\values.yaml"
    }
    
    Write-Info "Using values file: $valuesFile"
    
    # Helm install/upgrade
    $helmArgs = "--namespace $Namespace --timeout $Timeout"
    if ($WaitForDeployment) {
        $helmArgs += " --wait"
    }
    
    $chartPath = "$chartsDir\nash-pisharp-app"
    $helmCommand = "helm upgrade --install $ReleaseName $chartPath -f $valuesFile $helmArgs"
    
    Write-Info "Running: $helmCommand"
    Invoke-Expression $helmCommand
    
    Write-Success "Application deployed successfully"
    
    # Show deployment status
    Show-DeploymentStatus -Environment $Environment -Namespace $Namespace -ReleaseName $ReleaseName
}

function Update-Application {
    param(
        [string]$Environment,
        [string]$Namespace,
        [string]$ReleaseName,
        [string]$Timeout,
        [bool]$WaitForDeployment
    )
    
    Write-Info "Upgrading application..."
    
    # Check if release exists
    $existingRelease = helm list -n $Namespace | Select-String $ReleaseName
    if (-not $existingRelease) {
        Write-Error "Release $ReleaseName not found in namespace $Namespace"
        Write-Info "Use 'Deploy' command to install the application first"
        exit 1
    }
    
    Deploy-Application -Environment $Environment -Namespace $Namespace -ReleaseName $ReleaseName -Timeout $Timeout -WaitForDeployment $WaitForDeployment
}

function Rollback-Application {
    param(
        [string]$Namespace,
        [string]$ReleaseName
    )
    
    Write-Info "Rolling back application..."
    
    # Check if release exists
    $existingRelease = helm list -n $Namespace | Select-String $ReleaseName
    if (-not $existingRelease) {
        Write-Error "Release $ReleaseName not found in namespace $Namespace"
        exit 1
    }
    
    # Get revision to rollback to
    $revisions = helm history $ReleaseName -n $Namespace --max 5
    Write-Host $revisions
    
    $revision = Read-Host "Enter revision number to rollback to (or press Enter for previous)"
    
    $rollbackCmd = "helm rollback $ReleaseName"
    if ($revision) {
        $rollbackCmd += " $revision"
    }
    $rollbackCmd += " -n $Namespace"
    
    Write-Info "Running: $rollbackCmd"
    Invoke-Expression $rollbackCmd
    
    Write-Success "Application rolled back successfully"
    Show-DeploymentStatus -Namespace $Namespace -ReleaseName $ReleaseName
}

function Uninstall-Application {
    param(
        [string]$Namespace,
        [string]$ReleaseName
    )
    
    Write-Warning "This will remove the application from the cluster"
    $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
    if ($confirmation -notmatch '^[Yy]$') {
        Write-Info "Uninstall cancelled by user"
        exit 0
    }
    
    Write-Info "Uninstalling application..."
    helm uninstall $ReleaseName -n $Namespace
    
    Write-Success "Application uninstalled successfully"
}

function Show-DeploymentStatus {
    param(
        [string]$Environment = "",
        [string]$Namespace,
        [string]$ReleaseName
    )
    
    Write-Info "Deployment Status:"
    Write-Host ""
    
    # Helm release status
    Write-Info "Helm Release Status:"
    helm status $ReleaseName -n $Namespace
    Write-Host ""
    
    # Pod status
    Write-Info "Pod Status:"
    kubectl get pods -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName"
    Write-Host ""
    
    # Service status
    Write-Info "Service Status:"
    kubectl get services -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName"
    Write-Host ""
    
    # Ingress status
    Write-Info "Ingress Status:"
    try {
        kubectl get ingress -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName"
    }
    catch {
        Write-Host "No ingress found"
    }
    Write-Host ""
    
    # Get external access information
    try {
        $externalIp = kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        if ($externalIp) {
            Write-Success "Application accessible at: http://$externalIp"
        }
        else {
            Write-Info "External IP not yet assigned. Check with: kubectl get svc -n ingress-nginx"
        }
    }
    catch {
        Write-Info "Could not retrieve external IP information"
    }
}

function Show-ApplicationLogs {
    param(
        [string]$Namespace,
        [string]$ReleaseName
    )
    
    Write-Info "Application Logs:"
    
    # Get all pods
    $pods = kubectl get pods -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName" -o jsonpath='{.items[*].metadata.name}' 2>$null
    
    if (-not $pods) {
        Write-Warning "No pods found for release: $ReleaseName"
        exit 1
    }
    
    $podList = $pods -split ' '
    foreach ($pod in $podList) {
        if ($pod) {
            Write-Host ""
            Write-Info "Logs for pod: $pod"
            Write-Host "----------------------------------------"
            kubectl logs $pod -n $Namespace --tail=50
        }
    }
}

function Start-PortForwarding {
    param(
        [string]$Namespace,
        [string]$ReleaseName
    )
    
    Write-Info "Setting up port forwarding..."
    
    # Get frontend service
    $frontendService = kubectl get service -n $Namespace -l "app.kubernetes.io/name=frontend,app.kubernetes.io/instance=$ReleaseName" -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    # Get backend service
    $backendService = kubectl get service -n $Namespace -l "app.kubernetes.io/name=backend,app.kubernetes.io/instance=$ReleaseName" -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    if ($frontendService) {
        Write-Info "Port forwarding frontend service: $frontendService"
        Write-Host "Access frontend at: http://localhost:3000"
        Start-Process -FilePath "kubectl" -ArgumentList "port-forward", "service/$frontendService", "3000:80", "-n", $Namespace -NoNewWindow
    }
    
    if ($backendService) {
        Write-Info "Port forwarding backend service: $backendService"
        Write-Host "Access backend at: http://localhost:5000"
        Start-Process -FilePath "kubectl" -ArgumentList "port-forward", "service/$backendService", "5000:5000", "-n", $Namespace -NoNewWindow
    }
    
    Write-Info "Port forwarding setup completed"
    Write-Warning "Press Ctrl+C to stop port forwarding"
    
    # Keep the script running
    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-Info "Port forwarding stopped"
    }
}

# Main execution
if ($Help -or -not $Command) {
    Show-Usage
    exit 0
}

Show-Banner

Write-Info "Environment: $Environment"
Write-Info "Namespace: $Namespace"
Write-Info "Release: $ReleaseName"

$WaitForDeployment = -not $NoWait

# Run checks
Test-Prerequisites
Test-ClusterConnection

# Execute command
switch ($Command) {
    "Deploy" {
        Deploy-Application -Environment $Environment -Namespace $Namespace -ReleaseName $ReleaseName -Timeout $Timeout -WaitForDeployment $WaitForDeployment
    }
    "Upgrade" {
        Update-Application -Environment $Environment -Namespace $Namespace -ReleaseName $ReleaseName -Timeout $Timeout -WaitForDeployment $WaitForDeployment
    }
    "Rollback" {
        Rollback-Application -Namespace $Namespace -ReleaseName $ReleaseName
    }
    "Uninstall" {
        Uninstall-Application -Namespace $Namespace -ReleaseName $ReleaseName
    }
    "Status" {
        Show-DeploymentStatus -Environment $Environment -Namespace $Namespace -ReleaseName $ReleaseName
    }
    "Logs" {
        Show-ApplicationLogs -Namespace $Namespace -ReleaseName $ReleaseName
    }
    "PortForward" {
        Start-PortForwarding -Namespace $Namespace -ReleaseName $ReleaseName
    }
}

Write-Info "Script execution completed"