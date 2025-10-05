terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }
  }
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false  # Disable ServiceMonitor since Prometheus Operator not installed
          }
        }
        podSecurityContext = {
          runAsNonRoot = false  # Allow running as root for now
          # Remove user/group constraints
        }
        containerSecurityContext = {
          runAsNonRoot = false  # Allow running as root for now
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
            add  = ["NET_BIND_SERVICE"]
          }
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "90Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "256Mi"
          }
        }
        replicaCount = var.replica_count
        
        # Enable autoscaling for production
        autoscaling = {
          enabled = false  # Can be enabled later when needed
          minReplicas = 2
          maxReplicas = 10
          targetCPUUtilizationPercentage = 80
        }
      }
    })
  ]

  depends_on = [var.aks_cluster_id]

  # Wait for the LoadBalancer to be ready
  wait = true
  timeout = 600
}