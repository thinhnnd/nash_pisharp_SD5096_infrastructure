# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nash-pisharp"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "demo"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "DevOps Team"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# ECR Configuration
variable "ecr_enable_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "nash-pisharp-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "cluster_log_types" {
  description = "List of cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# EKS Node Group Configuration
variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group (ON_DEMAND, SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  description = "List of instance types for the EKS Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

# Jenkins Configuration
variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_volume_size" {
  description = "Root volume size in GB for Jenkins"
  type        = number
  default     = 30
}

variable "jenkins_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "jenkins_allowed_jenkins_cidrs" {
  description = "CIDR blocks allowed for Jenkins web access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "jenkins_create_key_pair" {
  description = "Whether to create a new key pair for Jenkins"
  type        = bool
  default     = false
}

variable "jenkins_public_key" {
  description = "Public key content for Jenkins key pair (required if jenkins_create_key_pair is true)"
  type        = string
  default     = ""
}

variable "jenkins_existing_key_pair_name" {
  description = "Name of existing key pair to use for Jenkins (required if jenkins_create_key_pair is false)"
  type        = string
  default     = ""
}

variable "jenkins_allocate_eip" {
  description = "Whether to allocate an Elastic IP for Jenkins"
  type        = bool
  default     = true
}

# S3 Configuration
variable "create_s3_bucket" {
  description = "Whether to create S3 bucket for build artifacts"
  type        = bool
  default     = true
}

# CloudWatch Configuration
variable "create_cloudwatch_logs" {
  description = "Whether to create CloudWatch log group for application logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}