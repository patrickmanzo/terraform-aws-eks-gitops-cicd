# --------------------------------------------------------------------------------------
# Minimal Configuration - VPC and EKS only
# --------------------------------------------------------------------------------------

# Enable only essential modules
enable_vpc = true
enable_eks = true
enable_ecr = true

# Disable everything else
enable_monitoring                   = false
enable_argo_cd                      = false
enable_jenkins                      = false
enable_rds                          = false
enable_bastion                      = false
enable_s3                           = false
enable_aws_load_balancer_controller = false

# Basic configuration
region      = "us-east-1"
environment = "dev"
project     = "finance"

# VPC Configuration
vpc_cidr_block       = "10.120.0.0/16"
public_subnet_cidrs  = ["10.120.1.0/24", "10.120.2.0/24", "10.120.3.0/24"]
private_subnet_cidrs = ["10.120.11.0/24", "10.120.12.0/24", "10.120.13.0/24"]

# EKS Configuration
# eks_kubernetes_version = null  # Uses latest available version by default
eks_node_group_ami_type = "AL2_x86_64"

# ECR Configuration
ecr_repository_name = "finance-app"

# GitHub configuration (required even when ArgoCD/Jenkins disabled - set via secrets)
# These are required variables, values come from GitHub secrets
github_repo_url = "https://github.com/patrickmanzo/terraform-aws-eks-gitops-cicd.git"
github_branch   = "main"
