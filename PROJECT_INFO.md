# Nash PiSharp SD5096 Infrastructure Project

## Overview

This is the infrastructure-as-code repository for the Nash PiSharp demo application, specifically designed for the SD5096 course.

## Project Details

- **Course**: SD5096 - DevOps and Cloud Computing
- **Application**: Nash PiSharp Todo App (React + Node.js + MongoDB)
- **Cloud Provider**: Microsoft Azure (primary), AWS (future)
- **Tools**: Terraform, Helm, Kubernetes, Docker

## Key Features

### Infrastructure Components
- **Azure Kubernetes Service (AKS)** - Container orchestration
- **Azure Container Registry (ACR)** - Private Docker registry
- **Virtual Network** - Secure networking
- **Log Analytics** - Monitoring and observability

### Application Architecture
- **Frontend**: React.js SPA
- **Backend**: Node.js/Express API
- **Database**: MongoDB with persistent storage
- **Ingress**: NGINX for external access

### DevOps Practices
- Infrastructure as Code (Terraform)
- Container orchestration (Kubernetes)
- Package management (Helm)
- Environment separation (dev/prod)
- Security policies and RBAC

## Quick Start

1. **Prerequisites**: Azure CLI, Terraform, Helm, kubectl
2. **Bootstrap**: Create Azure resources for Terraform state
3. **Deploy**: Run Terraform to create infrastructure
4. **Application**: Deploy using Helm charts

## Module Structure

```
├── bootstrap/   # Foundation (Resource Group, Storage, KeyVault)
├── vnet/       # Networking (Virtual Network, Subnets, NSGs)
├── acr/        # Container Registry (Shared across environments)
├── aks/        # Kubernetes Cluster (Main workload platform)
└── vm/         # Virtual Machines (Optional, for additional workloads)
```

## Environment Support

- **Development**: Single node, minimal resources, no authentication
- **Production**: Multiple nodes, resource limits, security enabled

## Security Features

- Pod Security Standards
- Network Policies
- RBAC enabled
- Resource Quotas and Limits
- Secret management with KeyVault integration

## Monitoring & Observability

- Log Analytics workspace
- Ready for Prometheus/Grafana integration
- Service monitoring capabilities
- Health checks and probes

---

**Course**: SD5096 DevOps  
**Author**: Nash PiSharp Team  
**Last Updated**: October 2025
