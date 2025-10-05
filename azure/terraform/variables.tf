# General configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nash-pisharp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-nash-pisharp-demo"
}

# Bootstrap variables
variable "storage_account_name" {
  description = "Name of the storage account for Terraform state"
  type        = string
  default     = "sanashpisharptfstate"
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "kv-nash-pisharp-demo"
}

# Network variables
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-nash-pisharp"
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_subnet_cidr" {
  description = "CIDR block for VM subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ACR variables
variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "acrnashpisharp"
}

variable "acr_sku" {
  description = "SKU of the Azure Container Registry"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = true
}

# AKS variables
variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-nash-pisharp"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-nash-pisharp"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33.1"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

# No VM configuration needed for this deployment
