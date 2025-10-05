# Network outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vnet.vnet_id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.vnet.aks_subnet_id
}

# ACR outputs
output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.acr.acr_id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "acr_admin_username" {
  description = "Admin username for ACR"
  value       = module.acr.acr_admin_username
}

output "acr_admin_password" {
  description = "Admin password for ACR"
  value       = module.acr.acr_admin_password
  sensitive   = true
}

# AKS outputs
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_endpoint" {
  description = "Endpoint of the AKS cluster"
  value       = module.aks.cluster_endpoint
  sensitive   = true
}

output "aks_cluster_ca_certificate" {
  description = "CA certificate of the AKS cluster"
  value       = module.aks.cluster_ca_certificate
  sensitive   = true
}

output "kube_config" {
  description = "Kube config for the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

# Ingress outputs
output "ingress_ip" {
  description = "External IP address of the NGINX Ingress Controller"
  value       = module.ingress.ingress_ip
}

output "ingress_namespace" {
  description = "Namespace where NGINX Ingress Controller is installed"
  value       = module.ingress.ingress_namespace
}

# No VM outputs needed
