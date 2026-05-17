# --------------------------------------------------------------------------------------
# Feature Flags - Enable/Disable Modules                                              #
# --------------------------------------------------------------------------------------
variable "enable_vpc" {
  description = "Enable VPC module"
  type        = bool
  default     = true
}

variable "enable_eks" {
  description = "Enable EKS module"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring module (Prometheus/Grafana)"
  type        = bool
  default     = true
}

variable "enable_argo_cd" {
  description = "Enable ArgoCD module"
  type        = bool
  default     = true
}

variable "enable_jenkins" {
  description = "Enable Jenkins module"
  type        = bool
  default     = false # Default off for testing
}

variable "enable_rds" {
  description = "Enable RDS module"
  type        = bool
  default     = false # Default off for testing
}

variable "enable_ecr" {
  description = "Enable ECR module"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_bastion" {
  description = "Enable Bastion host"
  type        = bool
  default     = false
}

variable "enable_s3" {
  description = "Enable S3 module"
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------------------
# Terraform State
# --------------------------------------------------------------------------------------
variable "bucket_name" {
  description = "The name of the S3 bucket for Terraform state"
  type        = string
  default     = "terraform-state-backend-343104031682-finance-dev"
}

variable "enable_kubernetes_resources" {
  description = "Enable Kubernetes and Helm provider resources"
  type        = bool
  default     = true
}

# --------------------------------------------------------------------------------------
# VPC Variables                                                                        #
# --------------------------------------------------------------------------------------
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for deployment."
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type        = string
  default     = "finance"
  description = "The project name for resource tagging and naming."
}

variable "vpc_cidr_block" {
  type        = string
  default     = "10.120.0.0/16"
  description = "CIDR block for the VPC."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.120.1.0/24", "10.120.2.0/24", "10.120.3.0/24"]
  description = "CIDR blocks for public subnets."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.120.11.0/24", "10.120.12.0/24", "10.120.13.0/24"]
  description = "CIDR blocks for private subnets."
}

variable "key_name" {
  type        = string
  default     = "localstack-key" # This key must exist in LocalStack/AWS
  description = "Name of the SSH key pair."
}

variable "ami_id" {
  type        = string
  default     = null # Let the module decide, or specify if needed for specific tests
  description = "Optional: Specific AMI ID to use for EC2. If null, module will find a default."
}

variable "security_level" {
  type        = string
  default     = "Low" # Default security level
  description = "Security level for tagging and resource management."
}

variable "account_id" {
  type        = string
  default     = "343104031682"
  description = "Account ID for tagging purposes."
}

variable "ecr_repository_name" {
  description = "Name for the ECR repository."
  default     = "devops-ecr-repo"
  type        = string
}

# --------------------------------------------------------------------------------------
# EKS Variables                                                                        #
# --------------------------------------------------------------------------------------
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster. Set to null to use latest available."
  type        = string
  default     = null # Use latest available version
}
#
#variable "eks_node_group_instance_types" {
#  description = "List of instance types for the EKS managed node group."
#  type        = list(string)
#  default     = ["t3.xlarge"]
#}
#
#variable "eks_node_group_min_size" {
#  description = "Minimum size of the EKS node group."
#  type        = number
#  default     = 1
#}
#
#variable "eks_node_group_max_size" {
#  description = "Maximum size of the EKS node group."
#  type        = number
#  default     = 2 # Start small for dev
#}
#
#variable "eks_node_group_desired_size" {
#  description = "Desired size of the EKS node group."
#  type        = number
#  default     = 1
#}
#

variable "eks_node_group_ami_id" {
  description = "AMI ID customizada para o node group do EKS."
  type        = string
  default     = null
}

variable "eks_node_group_ami_type" {
  description = "Tipo de AMI para o node group do EKS (ex: AL2_x86_64, AL2023_x86_64, BOTTLEROCKET_x86_64)."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

# --------------------------------------------------------------------------------------
# RDS Variables                                                                        #
# --------------------------------------------------------------------------------------
# RDS Database Passwords (Marked as sensitive)
#variable "app_db_password" {
#  description = "Master password for the application PostgreSQL database."
#  type        = string
#  sensitive   = true
#  default     = "DevPassword123!" # Use a strong, random password for dev, but NOT for prod.
#}
#
#variable "oracle_db_password" {
#  description = "Master password for the Oracle database."
#  type        = string
#  sensitive   = true
#  default     = "OracleDevPass456!" # Use a strong, random password for dev, but NOT for prod.
#}

# --------------------------------------------------------------------------------------
# S3 Variables                                                                        #
# --------------------------------------------------------------------------------------
variable "app_bucket_name" {
  description = "The name of the S3 bucket for application data. Must be globally unique."
  type        = string
  default     = "finance-app-data-bucket"
}

# --------------------------------------------------------------------------------------
# GitHub Variables                                                                    #
# --------------------------------------------------------------------------------------
variable "github_pat" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
  default     = "" # Set via TF_VAR_github_pat in GitHub Actions
}

variable "github_user" {
  description = "GitHub username"
  type        = string
  default     = "" # Set via TF_VAR_github_user in GitHub Actions
}

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
  default     = "" # Set via TF_VAR_github_repo_url in GitHub Actions
}

variable "github_branch" {
  description = "GitHub branch to deploy from"
  type        = string
  default     = "main"
}

# --------------------------------------------------------------------------------------
# General Variables                                                                    #
# --------------------------------------------------------------------------------------
variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "finance-app"
}

# --------------------------------------------------------------------------------------
# RDS Variables                                                                        #
# --------------------------------------------------------------------------------------
variable "rds_use_aurora" {
  description = "Whether to use Aurora cluster (true) or standard RDS instance (false)"
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "financedb"
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
  default     = "pass12345"
}

variable "rds_publicly_accessible" {
  description = "Whether RDS instance should be publicly accessible"
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain backups"
  type        = string
  default     = "0"
}

# Aurora-specific variables
variable "rds_aurora_engine" {
  description = "Aurora engine type"
  type        = string
  default     = "aurora-postgresql"
}

variable "rds_aurora_engine_version" {
  description = "Aurora engine version"
  type        = string
  default     = "17.5"
}

variable "rds_aurora_parameter_group_family" {
  description = "Aurora parameter group family"
  type        = string
  default     = "aurora-postgresql17"
}

# Standard RDS instance variables
variable "rds_instance_engine" {
  description = "RDS engine type"
  type        = string
  default     = "postgres"
}

variable "rds_instance_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "17.6"
}

variable "rds_instance_parameter_group_family" {
  description = "RDS parameter group family"
  type        = string
  default     = "postgres17"
}
