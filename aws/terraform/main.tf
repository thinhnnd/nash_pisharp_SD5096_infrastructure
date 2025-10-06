terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Backend configuration will be provided during terraform init
    # Example:
    # bucket         = "nash-pisharp-terraform-state"
    # key            = "aws/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create VPC
module "vpc" {
  source = "./vpc"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Create ECR repositories
module "ecr" {
  source = "./ecr"

  project_name       = var.project_name
  environment        = var.environment
  enable_scan_on_push = var.ecr_enable_scan_on_push
}

# Create EKS cluster
module "eks" {
  source = "./eks"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = var.cluster_name
  kubernetes_version   = var.kubernetes_version
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  cluster_log_types    = var.cluster_log_types
  capacity_type        = var.capacity_type
  instance_types       = var.instance_types
  disk_size            = var.disk_size
  desired_size         = var.desired_size
  max_size             = var.max_size
  min_size             = var.min_size

  depends_on = [module.vpc]
}

# Create Jenkins instance
module "jenkins" {
  source = "./jenkins"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region
  cluster_name             = var.cluster_name
  vpc_id                   = module.vpc.vpc_id
  subnet_id                = module.vpc.public_subnet_ids[0] # Deploy in first public subnet
  instance_type            = var.jenkins_instance_type
  volume_size              = var.jenkins_volume_size
  allowed_ssh_cidrs        = var.jenkins_allowed_ssh_cidrs
  allowed_jenkins_cidrs    = var.jenkins_allowed_jenkins_cidrs
  create_key_pair          = var.jenkins_create_key_pair
  public_key               = var.jenkins_public_key
  existing_key_pair_name   = var.jenkins_existing_key_pair_name
  allocate_eip             = var.jenkins_allocate_eip

  depends_on = [module.vpc]
}

# S3 bucket for storing build artifacts (optional)
resource "aws_s3_bucket" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-artifacts-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-artifacts"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Build artifacts storage"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# CloudWatch Log Group for application logs (optional)
resource "aws_cloudwatch_log_group" "app_logs" {
  count             = var.create_cloudwatch_logs ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}