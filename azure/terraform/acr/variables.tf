variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "sku" {
  description = "SKU of the Azure Container Registry (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = true
}

variable "georeplications" {
  description = "List of geo-replications for Premium SKU"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}

variable "network_rule_set_enabled" {
  description = "Enable network rule set for Premium SKU"
  type        = bool
  default     = false
}

variable "network_rule_set" {
  description = "Network rule set configuration"
  type = object({
    default_action = string
    ip_rules = list(object({
      action   = string
      ip_range = string
    }))
    virtual_networks = list(object({
      action    = string
      subnet_id = string
    }))
  })
  default = {
    default_action   = "Allow"
    ip_rules         = []
    virtual_networks = []
  }
}

variable "encryption_enabled" {
  description = "Enable encryption for Premium SKU"
  type        = bool
  default     = false
}

variable "encryption" {
  description = "Encryption configuration"
  type = object({
    key_vault_key_id   = string
    identity_client_id = string
  })
  default = {
    key_vault_key_id   = null
    identity_client_id = null
  }
}

variable "trust_policy_enabled" {
  description = "Enable trust policy"
  type        = bool
  default     = false
}

variable "retention_policy_enabled" {
  description = "Enable retention policy"
  type        = bool
  default     = false
}

variable "retention_policy_days" {
  description = "Number of days to retain images"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
