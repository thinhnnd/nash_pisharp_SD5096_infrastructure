# =============================================================================
# TERRAFORM STATE MANAGEMENT CONFIGURATION
# =============================================================================
# This file configures where Terraform state is stored remotely.
# The backend storage was created manually before this deployment.

terraform {
  backend "azurerm" {
    resource_group_name  = "nash-pisharp-demo-tfstate-rg"
    storage_account_name = "nashpisharpdemotfstate"
    container_name       = "tfstate"
    key                  = "demo.terraform.tfstate"
  }
}

# Note: 
# - The backend storage was created manually before this terraform
# - This ensures state is stored remotely for team collaboration
# - State locking prevents concurrent modifications
# - All team members can access the same state file