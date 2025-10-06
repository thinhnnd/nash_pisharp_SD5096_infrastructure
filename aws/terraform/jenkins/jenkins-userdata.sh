#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    unzip \
    git \
    jq

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -y
apt-get install -y helm

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

# Install Java 11 (required for Jenkins)
apt-get install -y openjdk-11-jdk

# Install Jenkins
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update -y
apt-get install -y jenkins

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
sleep 30

# Create jenkins user in docker group (if not already)
usermod -aG docker jenkins

# Restart Jenkins to apply group changes
systemctl restart jenkins

# Configure AWS CLI for jenkins user (using instance profile)
sudo -u jenkins aws configure set region ${region}

# Configure kubectl for EKS cluster
sudo -u jenkins aws eks update-kubeconfig --region ${region} --name ${cluster_name}

# Install Jenkins plugins via CLI (optional)
# Create a script to install common plugins
cat > /tmp/install-plugins.sh << 'EOF'
#!/bin/bash
# Wait for Jenkins to be fully ready
while ! curl -s http://localhost:8080/login >/dev/null; do
    echo "Waiting for Jenkins to start..."
    sleep 10
done

# Install plugins
sudo -u jenkins java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ install-plugin \
    git \
    github \
    pipeline-stage-view \
    docker-workflow \
    kubernetes \
    aws-credentials \
    pipeline-aws \
    blueocean \
    -restart
EOF

chmod +x /tmp/install-plugins.sh
# Run in background
nohup /tmp/install-plugins.sh > /var/log/jenkins-plugin-install.log 2>&1 &

# Create initial Jenkins job (optional)
cat > /tmp/create-initial-job.groovy << 'EOF'
import jenkins.model.*
import hudson.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def jenkins = Jenkins.getInstance()

// Create Nash PiSharp pipeline job
def job = jenkins.createProject(WorkflowJob, "nash-pisharp-pipeline")
job.setDefinition(new CpsFlowDefinition("""
pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = '${region}'
        ECR_REGISTRY = '${aws_account_id}.dkr.ecr.${region}.amazonaws.com'
        EKS_CLUSTER_NAME = '${cluster_name}'
        PROJECT_NAME = '${project_name}'
        ENVIRONMENT = '${environment}'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/your-repo/nash-pisharp-app.git'
            }
        }
        
        stage('Build Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            script {
                                sh 'docker build -t \$ECR_REGISTRY/\$PROJECT_NAME-\$ENVIRONMENT-frontend:\$BUILD_NUMBER .'
                            }
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            script {
                                sh 'docker build -t \$ECR_REGISTRY/\$PROJECT_NAME-\$ENVIRONMENT-backend:\$BUILD_NUMBER .'
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh 'aws ecr get-login-password --region \$AWS_DEFAULT_REGION | docker login --username AWS --password-stdin \$ECR_REGISTRY'
                    sh 'docker push \$ECR_REGISTRY/\$PROJECT_NAME-\$ENVIRONMENT-frontend:\$BUILD_NUMBER'
                    sh 'docker push \$ECR_REGISTRY/\$PROJECT_NAME-\$ENVIRONMENT-backend:\$BUILD_NUMBER'
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh 'aws eks update-kubeconfig --region \$AWS_DEFAULT_REGION --name \$EKS_CLUSTER_NAME'
                    sh '''
                        helm upgrade --install nash-pisharp-app ./charts/nash-pisharp-app \\
                            --namespace nash-pisharp-\$ENVIRONMENT \\
                            --create-namespace \\
                            --set image.registry=\$ECR_REGISTRY \\
                            --set frontend.image.tag=\$BUILD_NUMBER \\
                            --set backend.image.tag=\$BUILD_NUMBER
                    '''
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
""", true))

jenkins.save()
EOF

# Make Jenkins setup script executable and run it
chmod +x /tmp/create-initial-job.groovy

# Create a script to get initial admin password
cat > /home/ubuntu/get-jenkins-password.sh << 'EOF'
#!/bin/bash
echo "Jenkins Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
EOF

chmod +x /home/ubuntu/get-jenkins-password.sh
chown ubuntu:ubuntu /home/ubuntu/get-jenkins-password.sh

# Create useful aliases for ubuntu user
cat >> /home/ubuntu/.bashrc << 'EOF'

# Useful aliases
alias k='kubectl'
alias tf='terraform'
alias jenkins-password='sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
alias jenkins-status='sudo systemctl status jenkins'
alias jenkins-logs='sudo journalctl -u jenkins -f'

# AWS CLI completion
complete -C '/usr/local/bin/aws_completer' aws

# Kubectl completion
source <(kubectl completion bash)
EOF

# Create Jenkins workspace directories
mkdir -p /var/lib/jenkins/workspace
chown -R jenkins:jenkins /var/lib/jenkins/workspace

# Log installation completion
echo "Jenkins installation completed at $(date)" >> /var/log/user-data.log
echo "Initial admin password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)" >> /var/log/user-data.log

# Create completion marker
touch /tmp/user-data-complete