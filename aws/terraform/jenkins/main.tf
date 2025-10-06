# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-"
  vpc_id      = var.vpc_id
  description = "Security group for Jenkins server"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Jenkins web interface
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_jenkins_cidrs
    description = "Jenkins web interface"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_jenkins_cidrs
    description = "HTTPS access"
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_jenkins_cidrs
    description = "HTTP access"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Role for Jenkins EC2 instance
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for Jenkins to access EKS and ECR
resource "aws_iam_policy" "jenkins" {
  name        = "${var.project_name}-${var.environment}-jenkins-policy"
  description = "IAM policy for Jenkins to access AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "jenkins" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins.arn
}

# Instance profile for Jenkins
resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-profile"
  role = aws_iam_role.jenkins.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Key pair for Jenkins (you should create this manually or use existing one)
resource "aws_key_pair" "jenkins" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = "${var.project_name}-${var.environment}-jenkins-key"
  public_key = var.public_key

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-key"
    Environment = var.environment
    Project     = var.project_name
  }
}

# User data script for Jenkins installation
locals {
  user_data = base64encode(templatefile("${path.module}/jenkins-userdata.sh", {
    region         = var.aws_region
    cluster_name   = var.cluster_name
    project_name   = var.project_name
    environment    = var.environment
  }))
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.instance_type
  key_name                = var.create_key_pair ? aws_key_pair.jenkins[0].key_name : var.existing_key_pair_name
  vpc_security_group_ids  = [aws_security_group.jenkins.id]
  subnet_id               = var.subnet_id
  iam_instance_profile    = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = true

  user_data = local.user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-${var.environment}-jenkins-root-volume"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins"
    Environment = var.environment
    Project     = var.project_name
    Type        = "jenkins"
  }
}

# Elastic IP for Jenkins (optional)
resource "aws_eip" "jenkins" {
  count    = var.allocate_eip ? 1 : 0
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-eip"
    Environment = var.environment
    Project     = var.project_name
  }
}