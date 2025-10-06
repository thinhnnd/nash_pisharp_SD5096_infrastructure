# Nash PiSharp AWS Infrastructure Architecture

## 🏗️ High-Level Architecture

```
                            ┌─────────────────────────────────────────────────────────────┐
                            │                         AWS Cloud                          │
                            │                       Region: us-east-1                     │
                            └─────────────────────────────────────────────────────────────┘
                                                       │
                            ┌─────────────────────────────────────────────────────────────┐
                            │                    VPC (10.0.0.0/16)                       │
                            ├─────────────────────────────────────────────────────────────┤
                            │                                                             │
                            │  ┌──────────────────┐    ┌──────────────────────────────┐  │
                            │  │  Public Subnets  │    │       Private Subnets        │  │
                            │  │  10.0.1.0/24     │    │       10.0.3.0/24           │  │
                            │  │  10.0.2.0/24     │    │       10.0.4.0/24           │  │
                            │  └──────────────────┘    └──────────────────────────────┘  │
                            │           │                            │                   │
                            │  ┌──────────────────┐    ┌──────────────────────────────┐  │
                            │  │  Jenkins VM      │    │        EKS Cluster           │  │
                            │  │  (t3.medium)     │    │                              │  │
                            │  │                  │    │  ┌─────────┐ ┌─────────────┐ │  │
                            │  │ • Ubuntu 22.04   │    │  │Frontend │ │   Backend   │ │  │
                            │  │ • Jenkins 2.4+   │────┼─►│(React)  │ │ (Node.js)  │ │  │
                            │  │ • Docker         │    │  │         │ │             │ │  │
                            │  │ • AWS CLI        │    │  └─────────┘ └─────────────┘ │  │
                            │  │ • kubectl        │    │                              │  │
                            │  │ • Helm           │    │  ┌──────────────────────────┐ │  │
                            │  │ • Terraform      │    │  │        MongoDB           │ │  │
                            │  └──────────────────┘    │  │    (Persistent Vol)      │ │  │
                            │                          │  └──────────────────────────┘ │  │
                            │                          └──────────────────────────────┘  │
                            │                                                             │
                            │  ┌──────────────────┐    ┌──────────────────────────────┐  │
                            │  │      ECR         │    │       Internet Gateway      │  │
                            │  │ • Frontend Image │    │                              │  │
                            │  │ • Backend Image  │    └──────────────────────────────┘  │
                            │  └──────────────────┘                                      │
                            │                                                             │
                            │                          ┌──────────────────────────────┐  │
                            │                          │      NAT Gateways           │  │
                            │                          │   (For Private Subnets)     │  │
                            │                          └──────────────────────────────┘  │
                            └─────────────────────────────────────────────────────────────┘
                                                       │
                            ┌─────────────────────────────────────────────────────────────┐
                            │                 Application Load Balancer                   │
                            │                      (internet-facing)                      │
                            └─────────────────────────────────────────────────────────────┘
                                                       │
                                              ┌─────────────────┐
                                              │     Internet    │
                                              │     Users       │
                                              └─────────────────┘
```

## 🔧 Component Details

### 1. Virtual Private Cloud (VPC)
- **CIDR Block**: 10.0.0.0/16
- **Multi-AZ**: Deployed across 2 Availability Zones
- **Public Subnets**: 
  - 10.0.1.0/24 (AZ-1a)
  - 10.0.2.0/24 (AZ-1b)
- **Private Subnets**: 
  - 10.0.3.0/24 (AZ-1a) 
  - 10.0.4.0/24 (AZ-1b)

### 2. Elastic Kubernetes Service (EKS)
- **Cluster Version**: 1.27
- **Worker Nodes**: 2-4 t3.medium instances
- **Networking**: AWS VPC CNI
- **Node Groups**: Managed node groups in private subnets
- **IAM**: Service-linked roles with OIDC provider

### 3. Elastic Container Registry (ECR)
- **Repositories**: 
  - nash-pisharp-demo-frontend
  - nash-pisharp-demo-backend
- **Features**: 
  - Image vulnerability scanning
  - Lifecycle policies
  - Cross-region replication ready

### 4. Jenkins CI/CD Server
- **Instance Type**: t3.medium (2 vCPU, 4GB RAM)
- **Operating System**: Ubuntu 22.04 LTS
- **Storage**: 30GB encrypted EBS volume
- **Networking**: Elastic IP, Public subnet deployment
- **Security**: Security group with restricted access

### 5. Application Load Balancer (ALB)
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Target Type**: IP targets (EKS pods)
- **Health Checks**: HTTP health checks on /api/ and /
- **SSL/TLS**: Ready for certificate attachment

### 6. Application Components

#### Frontend (React.js)
- **Container Port**: 3000
- **Resources**: 250m CPU, 256Mi RAM
- **Replicas**: 1-2 (configurable)
- **Health Checks**: HTTP on /

#### Backend (Node.js/Express)
- **Container Port**: 3000
- **Resources**: 250m CPU, 256Mi RAM
- **Replicas**: 1-2 (configurable)
- **Health Checks**: HTTP on /api/
- **Environment**: Production mode with MongoDB connection

#### Database (MongoDB)
- **Container Port**: 27017
- **Resources**: 250m CPU, 256Mi RAM
- **Storage**: 8GB persistent volume (EBS GP2)
- **Backup**: Volume snapshots available

## 🔒 Security Architecture

### Network Security
```
┌─────────────────────────────────────────────────────────────┐
│                    Security Groups                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │  Jenkins SG     │    │         EKS Node SG             │ │
│  │                 │    │                                 │ │
│  │ • SSH: 22       │    │ • All traffic from EKS         │ │
│  │ • HTTP: 8080    │    │ • HTTPS: 443 from ALB          │ │
│  │ • HTTPS: 443    │    │ • Custom ports for NodePort    │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   ALB Security Group                    │ │
│  │                                                         │ │
│  │ • HTTP: 80 (from Internet)                             │ │
│  │ • HTTPS: 443 (from Internet)                           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### IAM Roles and Policies
- **EKS Cluster Service Role**: Amazon EKS cluster policies
- **EKS Node Group Role**: Worker node, CNI, and ECR policies
- **AWS Load Balancer Controller Role**: ALB/NLB management permissions
- **Jenkins EC2 Role**: ECR, EKS, and S3 access for CI/CD

### Pod Security
- **Security Contexts**: Non-root user execution
- **Network Policies**: Restricted pod-to-pod communication
- **RBAC**: Role-based access control for Kubernetes resources
- **Secrets Management**: Kubernetes secrets for sensitive data

## 📊 Data Flow

### 1. CI/CD Pipeline Flow
```
Developer → Git Push → Jenkins → Build Images → Push to ECR → Deploy to EKS → ALB Routes Traffic
```

### 2. User Request Flow
```
Internet User → ALB → EKS Ingress → Frontend/Backend Pods → MongoDB Pod
```

### 3. Application Communication Flow
```
Frontend Pod ←→ Backend Pod ←→ MongoDB Pod
```

## 🔄 Deployment Patterns

### Blue-Green Deployment (Ready)
- Multiple environments using different namespaces
- ALB target group switching
- Zero-downtime deployments

### Rolling Updates (Default)
- Kubernetes rolling update strategy
- Health check-based progression
- Automatic rollback on failure

### Canary Deployments (Configurable)
- Traffic splitting using ALB weighted routing
- Gradual traffic migration
- A/B testing capabilities

## 🌐 Multi-Environment Support

### Development Environment
- Single node EKS cluster
- Smaller instance types
- No persistent storage
- HTTP-only ALB

### Staging Environment
- 2-node EKS cluster
- Standard instance types
- Persistent storage enabled
- HTTPS with staging certificates

### Production Environment
- 3+ node EKS cluster with autoscaling
- Production instance types
- Multi-AZ persistent storage
- HTTPS with production certificates
- Enhanced monitoring and logging

## 📈 Scalability Considerations

### Horizontal Scaling
- **EKS Cluster Autoscaler**: Automatic node scaling
- **Horizontal Pod Autoscaler**: Application-level scaling
- **ALB**: Automatic load balancer scaling

### Vertical Scaling
- **Node Groups**: Easy instance type changes
- **Pod Resources**: CPU/memory adjustments
- **Storage**: EBS volume expansion

### Geographic Scaling
- **Multi-Region**: Ready for cross-region deployment
- **CDN Integration**: CloudFront integration ready
- **Global Load Balancing**: Route 53 health checks

This architecture provides a robust, scalable, and secure foundation for the Nash PiSharp application on AWS, with built-in CI/CD automation and enterprise-grade security practices.