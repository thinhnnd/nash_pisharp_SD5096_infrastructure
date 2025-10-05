output "ingress_ip" {
  description = "External IP address of the NGINX Ingress Controller (use kubectl to get actual IP)"
  value       = "Run: kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "ingress_namespace" {
  description = "Namespace where NGINX Ingress Controller is installed"
  value       = helm_release.nginx_ingress.namespace
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.nginx_ingress.name
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = helm_release.nginx_ingress.status
}