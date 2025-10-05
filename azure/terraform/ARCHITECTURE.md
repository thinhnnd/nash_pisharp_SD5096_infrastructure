# Azure Infrastructure Architecture

## Component Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                     Resource Group                          │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ Bootstrap   │  │    VNet      │  │        ACR          │ │
│  │ - Storage   │  │ - Subnets    │  │ - Container Registry│ │
│  │ - KeyVault  │  │ - NSGs       │  │ - Admin enabled     │ │
│  └─────────────┘  └──────────────┘  └─────────────────────┘ │
│                           │                     │           │
│                           └─────────┬───────────┘           │
│                                     │                       │
│                    ┌────────────────▼─────────────────┐     │
│                    │              AKS                 │     │
│                    │ - Kubernetes Cluster             │     │
│                    │ - Node Pool                      │     │
│                    │ - Log Analytics                  │     │
│                    │ - RBAC enabled                   │     │
│                    │ - ACR Pull Role                  │     │
│                    └──────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Module Interaction Flow

1. **Bootstrap** → Creates foundational resources
2. **VNet** → Creates network infrastructure  
3. **ACR** → Creates container registry (independent)
4. **AKS** → Creates Kubernetes cluster (depends on VNet + ACR)

## Benefits of Separated ACR

- ✅ **Lifecycle Independence**: ACR can outlive AKS clusters
- ✅ **Multi-Environment**: One ACR can serve multiple clusters
- ✅ **Cost Optimization**: Shared registry across environments
- ✅ **Security**: Granular RBAC per component
- ✅ **Scalability**: Easy to add more clusters with same registry

## Deployment Order

```bash
terraform apply -target=module.bootstrap  # First time only
terraform apply -target=module.vnet       # Network foundation
terraform apply -target=module.acr        # Container registry
terraform apply -target=module.aks        # Kubernetes cluster
```

Or deploy all at once:
```bash
terraform apply  # Terraform handles dependencies automatically
```
