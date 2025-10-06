# General Outputs
output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# ECR Outputs
output "ecr_frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = module.ecr.frontend_repository_url
}

output "ecr_backend_repository_url" {
  description = "URL of the backend ECR repository"
  value       = module.ecr.backend_repository_url
}

output "ecr_registry_id" {
  description = "Registry ID where the repositories were created"
  value       = module.ecr.registry_id
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.oidc_issuer_url
}

# Jenkins Outputs
output "jenkins_instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = module.jenkins.jenkins_instance_id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins instance"
  value       = module.jenkins.jenkins_public_ip
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = module.jenkins.jenkins_url
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins instance"
  value       = module.jenkins.ssh_command
}

output "jenkins_eip" {
  description = "Elastic IP associated with Jenkins (if allocated)"
  value       = module.jenkins.jenkins_eip
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  value       = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].bucket : null
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for artifacts"
  value       = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].arn : null
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.create_cloudwatch_logs ? aws_cloudwatch_log_group.app_logs[0].name : null
}

# kubectl configuration command
output "kubectl_config_command" {
  description = "Command to configure kubectl for EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ECR login command
output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}