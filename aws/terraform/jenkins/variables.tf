variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Jenkins will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Jenkins (should be public subnet)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_jenkins_cidrs" {
  description = "CIDR blocks allowed for Jenkins web access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_key_pair" {
  description = "Whether to create a new key pair"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key content for the key pair (required if create_key_pair is true)"
  type        = string
  default     = ""
}

variable "existing_key_pair_name" {
  description = "Name of existing key pair to use (required if create_key_pair is false)"
  type        = string
  default     = ""
}

variable "allocate_eip" {
  description = "Whether to allocate an Elastic IP for Jenkins"
  type        = bool
  default     = true
}