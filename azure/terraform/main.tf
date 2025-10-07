# =============================================================================
# TERRAFORM PROVIDER CONFIGURATION
# =============================================================================
# This file defines the required Terraform version and providers.
# Backend configuration is now separated in backend-state-management.tf

terraform {
  required_version = ">=1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "nash-pisharp-demo-tfstate-rg"
    storage_account_name = "nashpisharpdemotfstate"
    container_name       = "tfstate"
    key                  = "demo.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.aks.cluster_endpoint
    client_certificate     = base64decode(module.aks.cluster_client_certificate)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
    client_key             = base64decode(module.aks.cluster_client_key)
  }
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.aks.cluster_endpoint
  client_certificate     = base64decode(module.aks.cluster_client_certificate)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  client_key             = base64decode(module.aks.cluster_client_key)
}

# Local values
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    CreatedDate = timestamp()
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Bootstrap module (create once manually)
# Uncomment when running for the first time
module "bootstrap" {
  source = "./bootstrap"
  
  resource_group_name   = var.resource_group_name
  location             = var.location
  storage_account_name = var.storage_account_name
  key_vault_name       = var.key_vault_name
  tags                 = local.common_tags
}

# VNet/Network module - Phụ thuộc vào Resource Group
module "vnet" {
  source = "./vnet"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  vnet_name          = var.vnet_name
  vnet_cidr          = var.vnet_cidr
  aks_subnet_cidr    = var.aks_subnet_cidr
  vm_subnet_cidr     = var.vm_subnet_cidr
  tags               = local.common_tags
  
  depends_on = [module.bootstrap]
}

# ACR module - Phụ thuộc vào Resource Group
module "acr" {
  source = "./acr"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  acr_name           = var.acr_name
  sku                = var.acr_sku
  admin_enabled      = var.acr_admin_enabled
  tags               = local.common_tags
  
  depends_on = [module.bootstrap]
}

# AKS module - Phụ thuộc vào VNet và ACR
module "aks" {
  source = "./aks"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  cluster_name       = var.cluster_name
  dns_prefix         = var.dns_prefix
  kubernetes_version = var.kubernetes_version
  node_count         = var.node_count
  vm_size            = var.vm_size
  subnet_id          = module.vnet.aks_subnet_id
  acr_id             = module.acr.acr_id
  tags               = local.common_tags
  
  depends_on = [module.bootstrap, module.vnet, module.acr]
}

# NGINX Ingress Controller module
module "ingress" {
  source = "./ingress"
  
  aks_cluster_id     = module.aks.cluster_id
  replica_count      = 2
  monitoring_enabled = false  # Disable until Prometheus Operator is installed
  tags               = local.common_tags
  
  depends_on = [module.aks]
}

# No VM module needed for this deployment
