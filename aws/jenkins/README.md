# Jenkins CI/CD Pipeline Documentation

## 📋 Overview

This Jenkins setup provides automated CI/CD pipelines for the Nash PiSharp application, focused on building and pushing Docker images to AWS ECR. The deployment to EKS is handled separately through GitOps workflows.

## 🏗️ Pipeline Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Source Code   │    │    Jenkins      │    │      ECR        │
│                 │    │                 │    │                 │
│  Frontend Repo  │───►│  Build Images   │───►│  Store Images   │
│  Backend Repo   │    │  Run Tests      │    │  Scan & Tag     │
└─────────────────┘    │  Push to ECR    │    └─────────────────┘
                       └─────────────────┘             │
                                │                      │
                                ▼                      ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   GitOps Repo   │    │   EKS Cluster   │
                       │                 │    │                 │
                       │ Update Manifests│◄───│ ArgoCD/Flux     │
                       │ New Image Tags  │    │ Pull & Deploy   │
                       └─────────────────┘    └─────────────────┘
```

## 📁 Pipeline Files

### 1. `Jenkinsfile` - Standard Pipeline
- **Purpose**: Complete CI/CD pipeline with build, push, and deploy
- **Usage**: Legacy support, includes EKS deployment (will be phased out)

### 2. `Jenkinsfile-BuildOnly` - Build & Push Pipeline (Recommended)
- **Purpose**: Build images and push to ECR only
- **Usage**: Modern GitOps-ready pipeline
- **Features**:
  - Parameterized builds
  - Multi-environment support
  - Artifact generation for GitOps
  - Enhanced error handling

## 🚀 Quick Start

### Step 1: Setup Jenkins Job

1. **Create New Pipeline Job**:
   ```
   Jenkins Dashboard → New Item → Pipeline → Enter name → OK
   ```

2. **Configure Pipeline**:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your infrastructure repository
   - **Script Path**: `aws/jenkins/Jenkinsfile-BuildOnly`

3. **Add Parameters** (if using parameterized build):
   - `BUILD_ENVIRONMENT`: Choice parameter (demo, dev, staging, prod)
   - `IMAGE_TAG_SUFFIX`: String parameter (optional)
   - `SKIP_CACHE`: Boolean parameter

### Step 2: Configure Credentials

Add these credentials in Jenkins (Manage Jenkins → Credentials):

1. **AWS Account ID**:
   - Kind: Secret text
   - ID: `aws-account-id`
   - Secret: Your 12-digit AWS account ID

2. **AWS Credentials** (if not using IAM roles):
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID and Secret Access Key

### Step 3: Run Pipeline

1. **Manual Build**:
   ```
   Job → Build with Parameters
   ```

2. **Automated Triggers**:
   - **Webhook**: Configure GitHub webhooks
   - **Poll SCM**: Set schedule like `H/5 * * * *`
   - **Cron**: Schedule builds like `H 2 * * *`

## 🔧 Pipeline Configuration

### Environment Variables

```groovy
environment {
    AWS_DEFAULT_REGION = 'us-east-1'
    PROJECT_NAME = 'nash-pisharp'
    FRONTEND_REPO = 'https://github.com/thinhnnd/nash_pisharp_SD5096_frontend.git'
    BACKEND_REPO = 'https://github.com/thinhnnd/nash_pisharp_SD5096_backend.git'
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `BUILD_ENVIRONMENT` | Choice | demo | Target environment |
| `IMAGE_TAG_SUFFIX` | String | "" | Optional tag suffix |
| `SKIP_CACHE` | Boolean | false | Skip Docker cache |

### Build Outputs

The pipeline generates several artifacts:

1. **Docker Images**:
   ```
   <account-id>.dkr.ecr.us-east-1.amazonaws.com/nash-pisharp-demo-frontend:<build-number>
   <account-id>.dkr.ecr.us-east-1.amazonaws.com/nash-pisharp-demo-backend:<build-number>
   ```

2. **image-manifest.json**:
   ```json
   {
     "build": {
       "number": "123",
       "environment": "demo",
       "tag": "123"
     },
     "images": {
       "frontend": {
         "full_image": "123456789.dkr.ecr.us-east-1.amazonaws.com/nash-pisharp-demo-frontend:123"
       }
     }
   }
   ```

3. **gitops-values.yaml**:
   ```yaml
   image:
     registry: 123456789.dkr.ecr.us-east-1.amazonaws.com
     tag: 123
   
   frontend:
     image:
       repository: nash-pisharp-demo-frontend
       tag: 123
   ```

## 🔄 GitOps Integration

### Workflow

1. **Developer** pushes code to frontend/backend repos
2. **Jenkins** detects changes and builds images
3. **Jenkins** pushes images to ECR
4. **Jenkins** generates GitOps artifacts
5. **GitOps Controller** (ArgoCD/Flux) detects new images
6. **GitOps Controller** updates Kubernetes manifests
7. **Application** is deployed to EKS

### ArgoCD Integration

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nash-pisharp-app
spec:
  source:
    repoURL: <gitops-repo>
    path: apps/nash-pisharp
    helm:
      valueFiles:
      - values.yaml
      - ../../jenkins-artifacts/gitops-values.yaml
```

### Flux Integration

```yaml
# flux-helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: nash-pisharp-app
spec:
  values:
    image:
      registry: 123456789.dkr.ecr.us-east-1.amazonaws.com
      tag: ${BUILD_NUMBER}
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. ECR Login Failed
```bash
Error: Cannot perform an interactive login from a non TTY device
```

**Solution**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check ECR permissions
aws ecr describe-repositories --region us-east-1
```

#### 2. Docker Build Failed
```bash
Error: failed to solve with frontend dockerfile.v0
```

**Solution**:
- Check Dockerfile syntax in source repositories
- Verify base images are accessible
- Check Docker daemon status: `docker info`

#### 3. Image Push Failed
```bash
Error: denied: requested access to the resource is denied
```

**Solution**:
- Verify ECR repository exists
- Check IAM permissions for ECR
- Ensure correct region configuration

### Debug Commands

```bash
# Check Jenkins agent
docker info
aws --version
kubectl version --client

# Check ECR repositories
aws ecr describe-repositories --region us-east-1

# Check Docker images
docker images | grep nash-pisharp

# Check ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <registry>
```

## 📊 Monitoring

### Build Metrics

Monitor these metrics in Jenkins:

- **Build Success Rate**: Target > 95%
- **Build Duration**: Typical 5-10 minutes
- **Queue Time**: Target < 2 minutes
- **Test Pass Rate**: Target 100%

### Alerts

Configure alerts for:
- Build failures
- Long build times (> 15 minutes)
- ECR push failures
- High queue times

### Logs

Key log locations:
- **Jenkins Logs**: `/var/log/jenkins/jenkins.log`
- **Build Logs**: Available in Jenkins web UI
- **Docker Logs**: `docker logs <container-id>`

## 🔐 Security Best Practices

### 1. Credentials Management
- Use Jenkins Credentials Store
- Prefer IAM roles over access keys
- Rotate credentials regularly
- Use least privilege principle

### 2. Image Security
- Enable ECR vulnerability scanning
- Use minimal base images
- Keep dependencies updated
- Scan images in pipeline

### 3. Pipeline Security
- Restrict pipeline execution to authorized users
- Use webhook tokens for GitHub integration
- Audit pipeline changes
- Implement approval processes for production

## 📚 Additional Resources

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [AWS ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitOps Principles](https://www.gitops.tech/)

## 🤝 Contributing

To modify the pipeline:

1. Test changes in development environment
2. Update documentation
3. Create pull request
4. Get approval from DevOps team
5. Deploy to production Jenkins

---

## 📞 Support

For pipeline issues:
- Check this documentation first
- Review Jenkins build logs
- Contact DevOps team with build number
- Create issue in infrastructure repository