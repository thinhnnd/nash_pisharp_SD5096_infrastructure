# 🚀 Nash PiSharp AWS Deployment Guide

## Complete Step-by-Step AWS Deployment

### 📋 Prerequisites Checklist

- [ ] AWS Account with admin permissions
- [ ] AWS CLI v2.0+ installed
- [ ] Terraform v1.0+ installed  
- [ ] Docker installed
- [ ] kubectl installed
- [ ] Helm v3.0+ installed
- [ ] SSH key pair created in AWS console

---

## 🎯 Deployment Steps

### Step 1: Initial Setup

```powershell
# Clone the infrastructure repository
git clone <your-infrastructure-repo>
cd nash_pisharp_SD5096_infrastructure

# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID, Secret Key, Region (us-east-1), Output format (json)

# Verify AWS configuration
aws sts get-caller-identity
```

### Step 2: Prepare SSH Key Pair

```powershell
# Create a new key pair in AWS (if you don't have one)
aws ec2 create-key-pair --key-name nash-pisharp-jenkins --query 'KeyMaterial' --output text > nash-pisharp-jenkins.pem

# Set proper permissions (Linux/Mac)
chmod 400 nash-pisharp-jenkins.pem

# For Windows, use icacls
icacls nash-pisharp-jenkins.pem /inheritance:r /grant:r "$env:USERNAME:(R)"
```

### Step 3: Infrastructure Deployment

```powershell
# Navigate to AWS terraform directory
cd aws/terraform

# Copy and customize variables
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars  # Edit with your values

# Key variables to update:
# - jenkins_existing_key_pair_name = "nash-pisharp-jenkins"
# - jenkins_allowed_ssh_cidrs = ["YOUR_PUBLIC_IP/32"]
# - jenkins_allowed_jenkins_cidrs = ["YOUR_PUBLIC_IP/32"]
```

**Important terraform.tfvars settings:**
```hcl
# Update these values
project_name                    = "nash-pisharp"
environment                     = "demo"
aws_region                     = "us-east-1"
jenkins_existing_key_pair_name = "nash-pisharp-jenkins"  # Your key pair name
jenkins_allowed_ssh_cidrs      = ["0.0.0.0/0"]  # Restrict in production
jenkins_allowed_jenkins_cidrs  = ["0.0.0.0/0"]  # Restrict in production
```

### Step 4: Deploy Infrastructure

```powershell
# Method 1: Automated script (Recommended)
cd ../..
./aws/scripts/setup-infrastructure.sh setup

# Method 2: Manual Terraform deployment
cd aws/terraform

# Create S3 backend
aws s3 mb s3://nash-pisharp-terraform-state-$(Get-Random) --region us-east-1

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment (takes 15-20 minutes)
terraform apply
```

### Step 5: Configure kubectl

```powershell
# Get cluster credentials
aws eks update-kubeconfig --region us-east-1 --name nash-pisharp-eks

# Verify connection
kubectl get nodes
kubectl get namespaces
```

### Step 6: Install AWS Load Balancer Controller

```powershell
# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
    -n kube-system `
    --set clusterName=nash-pisharp-eks `
    --set serviceAccount.create=false `
    --set region=us-east-1
```

### Step 7: Setup Jenkins

```powershell
# Get Jenkins public IP
cd aws/terraform
$JENKINS_IP = terraform output -raw jenkins_public_ip
Write-Host "Jenkins IP: $JENKINS_IP"

# SSH to Jenkins server
ssh -i nash-pisharp-jenkins.pem ubuntu@$JENKINS_IP

# On Jenkins server, get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Jenkins Initial Setup:**
1. Access Jenkins at `http://<JENKINS_IP>:8080`
2. Enter initial admin password
3. Install suggested plugins
4. Create admin user
5. Complete setup wizard

### Step 8: Configure Jenkins Credentials

Add these credentials in Jenkins (Manage Jenkins > Credentials):

1. **AWS Credentials**:
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Add your AWS Access Key ID and Secret Access Key

2. **AWS Account ID**:
   - Kind: Secret text
   - ID: `aws-account-id`
   - Secret: Your AWS account ID (12 digits)

### Step 9: Deploy Application

```powershell
# Method 1: Using deployment script
# First, prepare application code
git clone <your-frontend-repo> frontend
git clone <your-backend-repo> backend

# Deploy application
./aws/scripts/deploy.sh deploy

# Method 2: Using Jenkins Pipeline
# 1. Create new Pipeline job in Jenkins
# 2. Use SCM and point to your infrastructure repo
# 3. Specify Jenkinsfile path: aws/jenkins/Jenkinsfile
# 4. Build the pipeline
```

### Step 10: Verify Deployment

```powershell
# Check pods
kubectl get pods -n nash-pisharp-demo

# Check services
kubectl get services -n nash-pisharp-demo

# Check ingress (ALB)
kubectl get ingress -n nash-pisharp-demo

# Get ALB DNS name
$ALB_DNS = kubectl get ingress nash-pisharp-app -n nash-pisharp-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Application URL: http://$ALB_DNS"

# Test application
curl "http://$ALB_DNS"
curl "http://$ALB_DNS/api/"
```

---

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Terraform Apply Fails

**Issue**: Insufficient permissions or quota limits
```powershell
# Check AWS permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>

# Check service quotas
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A  # Running On-Demand instances
```

#### 2. EKS Cluster Not Accessible

**Issue**: kubectl can't connect to cluster
```powershell
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name nash-pisharp-eks

# Check IAM permissions
aws eks describe-cluster --name nash-pisharp-eks
```

#### 3. ALB Not Provisioning

**Issue**: Ingress doesn't get external IP
```powershell
# Check ALB controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
```

#### 4. Jenkins Connection Issues

**Issue**: Can't access Jenkins web interface
```powershell
# Check security group rules
aws ec2 describe-security-groups --group-ids <jenkins-sg-id>

# Check Jenkins service status
ssh -i nash-pisharp-jenkins.pem ubuntu@<jenkins-ip> 'sudo systemctl status jenkins'

# Check Jenkins logs
ssh -i nash-pisharp-jenkins.pem ubuntu@<jenkins-ip> 'sudo journalctl -u jenkins -f'
```

#### 5. ECR Push Permission Denied

**Issue**: Docker push to ECR fails
```powershell
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Check ECR repositories
aws ecr describe-repositories

# Verify IAM permissions for ECR
aws ecr get-authorization-token
```

---

## 📊 Monitoring and Maintenance

### Health Checks

```powershell
# Check all resources
./aws/scripts/setup-infrastructure.sh info

# Check cluster health
kubectl get nodes
kubectl top nodes
kubectl get pods -A

# Check application health
kubectl get pods -n nash-pisharp-demo
kubectl describe ingress nash-pisharp-app -n nash-pisharp-demo
```

### Log Monitoring

```powershell
# Application logs
kubectl logs -f deployment/nash-pisharp-app-frontend -n nash-pisharp-demo
kubectl logs -f deployment/nash-pisharp-app-backend -n nash-pisharp-demo
kubectl logs -f deployment/nash-pisharp-app-mongodb -n nash-pisharp-demo

# Jenkins logs
ssh -i nash-pisharp-jenkins.pem ubuntu@<jenkins-ip> 'sudo tail -f /var/log/jenkins/jenkins.log'

# ALB Controller logs
kubectl logs -f -n kube-system deployment/aws-load-balancer-controller
```

---

## 🧹 Cleanup Instructions

### Complete Cleanup

```powershell
# 1. Remove application
helm uninstall nash-pisharp-app -n nash-pisharp-demo
kubectl delete namespace nash-pisharp-demo

# 2. Remove ALB controller
helm uninstall aws-load-balancer-controller -n kube-system

# 3. Destroy infrastructure
./aws/scripts/setup-infrastructure.sh destroy

# 4. Clean up ECR images (optional)
aws ecr list-images --repository-name nash-pisharp-demo-frontend --query 'imageIds[*]' --output json | aws ecr batch-delete-image --repository-name nash-pisharp-demo-frontend --image-ids file:///dev/stdin

# 5. Delete key pair (optional)
aws ec2 delete-key-pair --key-name nash-pisharp-jenkins
Remove-Item nash-pisharp-jenkins.pem
```

---

## 🎯 Success Criteria

Your deployment is successful when:

- [ ] EKS cluster is running with 2+ worker nodes
- [ ] Jenkins is accessible and configured
- [ ] ECR repositories are created and accessible
- [ ] Application pods are running in `nash-pisharp-demo` namespace
- [ ] ALB ingress has external hostname
- [ ] Frontend is accessible via browser
- [ ] Backend API responds to `/api/` endpoint
- [ ] MongoDB is running and persistent

## 📞 Getting Help

If you encounter issues:

1. **Check this troubleshooting guide** first
2. **Review AWS CloudWatch logs** for detailed error messages
3. **Check Kubernetes events**: `kubectl get events -n nash-pisharp-demo`
4. **Verify resource quotas** in your AWS account
5. **Contact your AWS administrator** for permission issues

---

## 🎉 Congratulations!

You have successfully deployed Nash PiSharp application on AWS with:
- ✅ Scalable EKS cluster
- ✅ Automated CI/CD with Jenkins
- ✅ Container registry with ECR
- ✅ Load balancing with ALB
- ✅ Infrastructure as Code with Terraform

Your application is now ready for development and production use!