# --------------------------------------------------------------------------------------
# Testing Configuration - VPC, EKS, Monitoring, ArgoCD only
# --------------------------------------------------------------------------------------

# Enable only modules needed for testing
enable_vpc                          = true
enable_eks                          = true
enable_monitoring                   = true
enable_argo_cd                      = true
enable_ecr                          = true
enable_aws_load_balancer_controller = true

# Disable modules not needed for testing
enable_jenkins = true
enable_rds     = true
enable_bastion = false
enable_s3      = false

# Basic configuration
region      = "us-east-1"
environment = "dev"
project     = "finance"

# GitHub configuration (required for ArgoCD)
github_repo_url = "https://github.com/patrickmanzo/terraform-aws-eks-gitops-cicd.git"
github_branch   = "main"
# github_user and github_pat should be set via environment variables or secrets

# VPC Configuration
vpc_cidr_block       = "10.120.0.0/16"
public_subnet_cidrs  = ["10.120.1.0/24", "10.120.2.0/24", "10.120.3.0/24"]
private_subnet_cidrs = ["10.120.11.0/24", "10.120.12.0/24", "10.120.13.0/24"]

# EKS Configuration
# eks_kubernetes_version = null  # Uses latest available version by default
eks_node_group_ami_type = "AL2_x86_64"

# ECR Configuration
ecr_repository_name = "finance-app"

# --------------------------------------------------------------------------------------
# RDS Configuration (required when enable_rds = true)
# --------------------------------------------------------------------------------------
rds_use_aurora     = false
rds_instance_class = "db.t3.micro"
rds_database_name  = "financedb"
rds_username       = "postgres"
# rds_password should be set via GitHub secrets: TF_VAR_rds_password or TF_RDS_PASSWORD
rds_publicly_accessible             = true
rds_multi_az                        = false
rds_backup_retention_period         = 7
rds_instance_engine                 = "postgres"
rds_instance_engine_version         = "17.6"
rds_instance_parameter_group_family = "postgres17"
