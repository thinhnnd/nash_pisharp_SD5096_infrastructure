variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-nash-pisharp-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "nash-pisharp"
    ManagedBy   = "terraform"
  }
}
