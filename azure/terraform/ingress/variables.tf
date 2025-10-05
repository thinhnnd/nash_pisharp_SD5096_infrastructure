variable "replica_count" {
  description = "Number of NGINX Ingress Controller replicas"
  type        = number
  default     = 2
}

variable "monitoring_enabled" {
  description = "Enable Prometheus monitoring for NGINX Ingress"
  type        = bool
  default     = true
}

variable "aks_cluster_id" {
  description = "AKS cluster ID dependency"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}