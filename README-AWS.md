# Nash PiSharp AWS Infrastructure

This repository contains Infrastructure as Code (IaC) for deploying the Nash PiSharp demo application to AWS using Terraform, EKS, and Jenkins CI/CD.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                          AWS Cloud                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │    Jenkins VM   │    │            EKS Cluster           │ │
│  │   (Ubuntu 22.04)│    │  ┌─────────┐ ┌─────────────────┐ │ │
│  │                 │    │  │Frontend │ │    Backend      │ │ │
│  │ • Docker        │────┼─►│ (React) │ │  (Node.js)     │ │ │
│  │ • AWS CLI       │    │  │         │ │                 │ │ │
│  │ • kubectl       │    │  └─────────┘ └─────────────────┘ │ │
│  │ • Helm          │    │  ┌─────────────────────────────┐ │ │
│  │ • Terraform     │    │  │         MongoDB            │ │ │
│  └─────────────────┘    │  └─────────────────────────────┘ │ │
│                         └──────────────────────────────────┘ │
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │       ECR       │    │             ALB                  │ │
│  │  • Frontend     │    │    (Application Load Balancer)  │ │
│  │  • Backend      │    └──────────────────────────────────┘ │
│  └─────────────────┘                                         │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Components

### Infrastructure Components

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **EKS Cluster**: Managed Kubernetes cluster for running applications
- **ECR**: Container registry for storing Docker images
- **Jenkins VM**: EC2 instance with Jenkins for CI/CD automation
- **ALB**: Application Load Balancer for ingress traffic
- **IAM Roles**: Proper permissions for all components

### Application Components

- **Frontend**: React.js application
- **Backend**: Node.js/Express API server
- **Database**: MongoDB with persistent storage
- **Ingress**: AWS ALB Ingress Controller for traffic routing

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** (v2.0+) installed and configured
3. **Terraform** (v1.0+) installed
4. **Docker** installed
5. **kubectl** installed
6. **Helm** (v3.0+) installed

### Step 1: Clone Repository

```bash
git clone <your-infrastructure-repo>
cd nash_pisharp_SD5096_infrastructure
```

### Step 2: Automated Setup

```bash
# Make scripts executable
chmod +x aws/scripts/*.sh

# Run complete infrastructure setup
./aws/scripts/setup-infrastructure.sh setup
```

This script will:
- Create Terraform S3 backend
- Initialize Terraform
- Create terraform.tfvars from template
- Plan and apply infrastructure
- Install AWS Load Balancer Controller
- Display deployment information

### Step 3: Access Jenkins

1. SSH to Jenkins instance:
```bash
ssh -i <your-key>.pem ubuntu@<jenkins-public-ip>
```

2. Get initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

3. Access Jenkins at `http://<jenkins-public-ip>:8080`

### Step 4: Deploy Application

Option 1 - Using Jenkins Pipeline:
1. Create a new Pipeline job in Jenkins
2. Use the provided `Jenkinsfile`
3. Configure your application repository URLs
4. Run the pipeline

Option 2 - Using Deploy Script:
```bash
# Clone your application repositories to frontend/ and backend/ directories
git clone <frontend-repo> frontend
git clone <backend-repo> backend

# Deploy application
./aws/scripts/deploy.sh deploy
```

## 📁 Repository Structure

```
nash_pisharp_SD5096_infrastructure/
├── aws/
│   ├── terraform/              # Infrastructure as Code
│   │   ├── main.tf            # Main Terraform configuration
│   │   ├── variables.tf       # Variable definitions
│   │   ├── outputs.tf         # Output values
│   │   ├── terraform.tfvars.example  # Example variables
│   │   ├── vpc/               # VPC module
│   │   ├── ecr/               # ECR module
│   │   ├── eks/               # EKS module
│   │   └── jenkins/           # Jenkins EC2 module
│   ├── charts/                # Helm charts
│   │   └── nash-pisharp-app/  # Application Helm chart
│   ├── jenkins/               # Jenkins configuration
│   │   └── Jenkinsfile        # Pipeline definition
│   └── scripts/               # Automation scripts
│       ├── setup-infrastructure.sh  # Infrastructure setup
│       └── deploy.sh          # Application deployment
├── shared/                    # Shared configurations
└── README-AWS.md             # This file
```

## 🔧 Configuration

### Terraform Variables

Key variables in `terraform.tfvars`:

```hcl
# General configuration
project_name = "nash-pisharp"
environment  = "demo"
aws_region   = "us-east-1"

# EKS configuration
cluster_name       = "nash-pisharp-eks"
kubernetes_version = "1.27"
desired_size       = 2
max_size          = 4
min_size          = 1

# Jenkins configuration
jenkins_instance_type          = "t3.medium"
jenkins_existing_key_pair_name = "your-key-pair"
jenkins_allocate_eip          = true
```

### Environment-Specific Deployments

Deploy to different environments using values files:

```bash
# Development
./aws/scripts/deploy.sh deploy latest values-dev.yaml

# Production
./aws/scripts/deploy.sh deploy v1.0.0 values-prod.yaml
```

## 🔐 Security Considerations

### Implemented Security Features

- **VPC**: Private subnets for EKS workers
- **Security Groups**: Restrictive ingress/egress rules
- **IAM**: Least privilege access policies
- **ECR**: Image vulnerability scanning
- **EKS**: Pod security contexts and network policies
- **Storage**: Encrypted EBS volumes and S3 buckets

### Security Best Practices

1. **Restrict CIDR blocks** in terraform.tfvars for SSH and Jenkins access
2. **Use IAM roles** instead of access keys where possible
3. **Enable AWS CloudTrail** for audit logging
4. **Configure VPC Flow Logs** for network monitoring
5. **Use AWS Secrets Manager** for sensitive data
6. **Regularly update** container images and dependencies

## 🔍 Monitoring and Troubleshooting

### Useful Commands

```bash
# Check infrastructure status
./aws/scripts/setup-infrastructure.sh info

# Verify EKS cluster
kubectl get nodes
kubectl get pods -A

# Check application status
kubectl get pods -n nash-pisharp-demo
kubectl get services -n nash-pisharp-demo
kubectl get ingress -n nash-pisharp-demo

# View application logs
kubectl logs -f deployment/nash-pisharp-app-frontend -n nash-pisharp-demo
kubectl logs -f deployment/nash-pisharp-app-backend -n nash-pisharp-demo

# Check ALB status
kubectl describe ingress nash-pisharp-app -n nash-pisharp-demo

# Jenkins logs
ssh ubuntu@<jenkins-ip> 'sudo journalctl -u jenkins -f'
```

### Common Issues

1. **ALB Not Provisioning**
   - Check AWS Load Balancer Controller is installed
   - Verify IAM permissions for ALB controller
   - Check subnet tags for ALB

2. **Pods Not Starting**
   - Check ECR image permissions
   - Verify node group capacity
   - Review resource requests/limits

3. **Jenkins Build Failures**
   - Check AWS credentials configuration
   - Verify ECR login
   - Check Docker daemon status

## 💰 Cost Optimization

### Cost Components

- **EKS Cluster**: ~$73/month (control plane)
- **EC2 Instances**: Variable based on instance types and count
- **ALB**: ~$22/month + data processing
- **ECR**: Storage and data transfer costs
- **EBS Volumes**: Storage costs

### Cost Reduction Tips

1. **Use Spot Instances** for EKS worker nodes (development environments)
2. **Enable Cluster Autoscaler** to scale down unused nodes
3. **Use smaller instance types** for development
4. **Clean up unused ECR images** regularly
5. **Schedule Jenkins instance** to run only during work hours

## 🔄 CI/CD Pipeline

### Jenkins Pipeline Features

- **Parallel Builds**: Frontend and backend build in parallel
- **Multi-stage Deployment**: Build → Push → Deploy → Verify
- **Smoke Tests**: Automated health checks after deployment
- **Rollback Support**: Easy rollback to previous versions
- **Notifications**: Success/failure notifications

### Pipeline Configuration

1. **Source Code**: Configure repository URLs in Jenkinsfile
2. **Credentials**: Add AWS credentials in Jenkins
3. **Webhooks**: Configure Git webhooks for automatic triggers
4. **Environments**: Use different values files for dev/staging/prod

## 🧹 Cleanup

### Destroy Infrastructure

```bash
# Destroy all AWS resources
./aws/scripts/setup-infrastructure.sh destroy

# Clean up Terraform state (optional)
aws s3 rm s3://<terraform-state-bucket> --recursive
aws dynamodb delete-table --table-name <terraform-lock-table>
```

### Partial Cleanup

```bash
# Remove application only
helm uninstall nash-pisharp-app -n nash-pisharp-demo
kubectl delete namespace nash-pisharp-demo

# Clean up Docker images
./aws/scripts/deploy.sh cleanup
```

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review AWS CloudWatch logs
- Contact the DevOps team

---

## 🎯 Next Steps

- [ ] Implement GitOps with ArgoCD
- [ ] Add Prometheus/Grafana monitoring
- [ ] Implement backup strategies
- [ ] Add multi-region deployment
- [ ] Integrate with AWS CodeCommit/CodeBuild
- [ ] Add security scanning with Trivy
- [ ] Implement blue-green deployments