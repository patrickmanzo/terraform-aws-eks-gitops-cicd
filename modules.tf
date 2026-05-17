# --------------------------------------------------------------------------------------
### S3 Backend Module - Created externally with AWS CLI, not managed by Terraform
# module "s3_backend" {
#   source      = "./modules/s3_backend"
#   bucket_name = var.bucket_name
#   table_name  = var.table_name
#   region      = var.region
# }

# --------------------------------------------------------------------------------------
### VPC Module
module "vpc" {
  count = var.enable_vpc ? 1 : 0

  source               = "./modules/vpc"
  environment          = local.environment
  project              = local.project
  name_prefix          = local.name_prefix
  vpc_cidr_block       = var.vpc_cidr_block
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  common_tags          = local.common_tags
}

# --------------------------------------------------------------------------------------
### ECR Module
module "ecr" {
  count = var.enable_ecr ? 1 : 0

  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
  scan_on_push    = false
  common_tags     = local.common_tags
}

# --------------------------------------------------------------------------------------
### Load Balancer Module
#module "lb" {
#  source                     = "./modules/lb"
#  name                       = "${local.name_prefix}-nlb"
#  internal                   = false
#  subnet_ids                 = module.vpc.public_subnet_ids
#  enable_deletion_protection = false
#  access_logs = {
#    enabled = false
#    bucket  = ""
#    prefix  = ""
#  }
#  common_tags                = local.common_tags
#  target_group_name          = "${local.name_prefix}-lb-tg"
#  target_group_port          = 443
#  target_group_protocol      = "TCP"
#  vpc_id                     = module.vpc.vpc_id
#  listener_port              = 443
#  listener_protocol          = "TCP"
#}

# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
# Pre-destroy cleanup for ALB resources
# This MUST run before EKS is destroyed to allow ALB Controller to clean up ALBs
# --------------------------------------------------------------------------------------
resource "null_resource" "alb_cleanup_before_eks_destroy" {
  count = var.enable_eks && var.enable_vpc ? 1 : 0

  triggers = {
    cluster_name = "${local.name_prefix}-eks-cluster"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "🧹 Pre-EKS Destroy: Cleaning up ALB resources..."

      # Check if kubectl is available and cluster is accessible
      if kubectl cluster-info &>/dev/null; then
        echo "✅ Cluster accessible - deleting all Ingress resources"

        # Delete ALL ingresses in ALL namespaces
        # This triggers ALB Controller to delete the ALBs before the controller is destroyed
        echo "🔧 Deleting all Ingress resources..."
        kubectl delete ingress --all-namespaces --all --timeout=120s 2>/dev/null || true

        # Wait for ALB Controller to process deletions
        echo "⏳ Waiting 120s for ALB Controller to delete Load Balancers..."
        sleep 120

        # Verify no ingresses remain
        remaining=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
        if [ "$remaining" -gt 0 ]; then
          echo "⚠️ $remaining ingresses still exist, forcing deletion..."
          kubectl get ingress -A -o name 2>/dev/null | while read ing; do
            ns=$(echo $ing | cut -d'/' -f1)
            name=$(echo $ing | cut -d'/' -f2)
            kubectl patch $ing -n $ns -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            kubectl delete $ing -n $ns --force --grace-period=0 2>/dev/null || true
          done
          sleep 30
        fi

        echo "✅ ALB cleanup completed"
      else
        echo "⚠️ Cluster not accessible - ALBs may need manual cleanup"
      fi
    EOT
    on_failure = continue
  }
}

## EKS Module
module "eks" {
  count = var.enable_eks && var.enable_vpc ? 1 : 0

  source              = "./modules/eks"
  project             = local.project
  environment         = local.environment
  name_prefix         = local.name_prefix
  cluster_name        = "${local.name_prefix}-eks-cluster"
  kubernetes_version  = var.eks_kubernetes_version # null = use latest
  vpc_id              = module.vpc[0].vpc_id
  vpc_cidr_block      = module.vpc[0].vpc_cidr_block
  private_subnet_ids  = module.vpc[0].private_subnet_ids
  public_subnet_ids   = module.vpc[0].public_subnet_ids
  node_group_ami_id   = var.eks_node_group_ami_id
  node_group_ami_type = var.eks_node_group_ami_type
  common_tags         = local.common_tags

  depends_on = [
    module.vpc,
    null_resource.alb_cleanup_before_eks_destroy
  ]
}

# --------------------------------------------------------------------------------------
# Shared EBS Storage Class for all modules (Jenkins, Monitoring, etc.)
# Created at root level to avoid Kubernetes provider cycle with EKS module
# --------------------------------------------------------------------------------------
resource "kubernetes_storage_class_v1" "ebs_sc" {
  count = var.enable_eks && var.enable_kubernetes_resources ? 1 : 0

  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
  }

  depends_on = [module.eks]
}

#data "aws_eks_cluster" "eks" {
#  name       = module.eks.eks_cluster_name
#  depends_on = [module.eks]
#}
#
#data "aws_eks_cluster_auth" "eks" {
#  name       = module.eks.eks_cluster_name
#  depends_on = [module.eks]
#}

## --------------------------------------------------------------------------------------
## EC2 Module
#module "ec2" {
#  source                  = "../../modules/ec2"
#  ami_id                  = var.ami_id
#  instance_name           = "${local.name_prefix}-ec2-instance"
#  subnet_id               = module.vpc.public_subnet_ids[0]
#  key_name                = var.key_name
#  environment             = var.environment
#  vpc_id                  = module.vpc.vpc_id
#  common_tags             = local.common_tags
#  name_prefix             = local.name_prefix
#  depends_on              = [module.vpc]
#}

# --------------------------------------------------------------------------------------
# Bastion Module
module "bastion" {
  count = var.enable_bastion && var.enable_vpc ? 1 : 0

  source = "./modules/bastion"

  # Basic configuration
  vpc_id         = module.vpc[0].vpc_id
  subnet_id      = module.vpc[0].public_subnet_ids[0] # Deploy in public subnet
  vpc_cidr_block = module.vpc[0].vpc_cidr_block

  # Naming and tagging
  name_prefix = local.name_prefix
  environment = var.environment
  project     = var.project
  common_tags = local.common_tags

  # Instance configuration
  instance_type = "t3.micro"   # Free tier eligible
  key_name      = var.key_name # Optional SSH key

  # Security configuration
  allowed_cidr_blocks = ["0.0.0.0/0"] # Restrict this in production!

  # Integration configuration
  eks_cluster_name = var.enable_eks ? module.eks[0].eks_cluster_name : ""

  # Features
  enable_session_manager = true
  create_s3_bucket       = true

  depends_on = [module.vpc]
}

# --------------------------------------------------------------------------------------
### Security Groups Module
#module "security_groups" {
#  source      = "./modules/security_groups"
#  vpc_id      = module.vpc.vpc_id
#  name_prefix = local.name_prefix
#  common_tags = local.common_tags
#
#  # EC2 Security Group Rules
#  ingress_rules = [
#    {
#      from_port   = 22
#      to_port     = 22
#      protocol    = "tcp"
#      cidr_blocks = ["10.120.0.0/16"]
#      description = "Allow SSH from VPC CIDR"
#    }
#  ]
#  egress_rules = [
#    {
#      from_port   = 0
#      to_port     = 0
#      protocol    = "-1"
#      cidr_blocks = ["0.0.0.0/0"]
#      description = "Allow all outbound"
#    }
#  ]
#
#  # EKS Security Group Rules
#  eks_ingress = [
#    {
#      from_port   = 443
#      to_port     = 443
#      protocol    = "tcp"
#      cidr_blocks = ["10.120.0.0/16"]
#      description = "Allow HTTPS to EKS"
#    }
#  ]
#  eks_egress = [
#    {
#      from_port   = 0
#      to_port     = 0
#      protocol    = "-1"
#      cidr_blocks = ["0.0.0.0/0"]
#      description = "Allow all outbound from EKS"
#    }
#  ]
#
#  # RDS Security Group Rules
#  rds_ingress = [
#    {
#      from_port   = 5432
#      to_port     = 5432
#      protocol    = "tcp"
#      cidr_blocks = ["10.120.0.0/16"]
#      description = "Allow Postgres from VPC"
#    }
#  ]
#  rds_egress = [
#    {
#      from_port   = 0
#      to_port     = 0
#      protocol    = "-1"
#      cidr_blocks = ["0.0.0.0/0"]
#      description = "Allow all outbound from RDS"
#    }
#  ]
#
#  # Lambda Security Group Rules
#  lambda_ingress = []
#  lambda_egress = [
#    {
#      from_port   = 443
#      to_port     = 443
#      protocol    = "tcp"
#      cidr_blocks = ["0.0.0.0/0"]
#      description = "Allow Lambda outbound HTTPS"
#    }
#  ]
#}

# --------------------------------------------------------------------------------------
# RDS Module
module "rds" {
  count = var.enable_rds && var.enable_vpc ? 1 : 0

  source      = "./modules/rds"
  common_tags = local.common_tags

  name                  = "${var.name}-db"
  use_aurora            = var.rds_use_aurora
  aurora_instance_count = 1
  vpc_cidr_block        = module.vpc[0].vpc_cidr_block

  # --- Aurora-only ---
  engine_cluster                = var.rds_aurora_engine
  engine_version_cluster        = var.rds_aurora_engine_version
  parameter_group_family_aurora = var.rds_aurora_parameter_group_family

  # --- RDS-only ---
  engine                     = var.rds_instance_engine
  engine_version             = var.rds_instance_engine_version
  parameter_group_family_rds = var.rds_instance_parameter_group_family

  # Common
  instance_class          = var.rds_instance_class
  allocated_storage       = 20
  db_name                 = var.rds_database_name
  username                = var.rds_username
  password                = var.rds_password
  subnet_private_ids      = module.vpc[0].private_subnet_ids
  subnet_public_ids       = module.vpc[0].public_subnet_ids
  publicly_accessible     = var.rds_publicly_accessible
  vpc_id                  = module.vpc[0].vpc_id
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  parameters = {
    max_connections            = "200"
    log_min_duration_statement = "500"
  }

  tags = local.common_tags
  depends_on = [
    module.vpc
  ]
}

# --------------------------------------------------------------------------------------
# S3 Module
module "s3" {
  count = var.enable_s3 ? 1 : 0

  source                = "./modules/s3"
  app_bucket_name       = var.app_bucket_name
  aws_region            = var.region
  environment           = var.environment
  project               = var.project
  name_prefix           = local.name_prefix
  enable_access_logging = false
  common_tags           = local.common_tags
}

# --------------------------------------------------------------------------------------
# Jenkins Module
module "jenkins" {
  count = var.enable_jenkins && var.enable_eks && var.enable_ecr && var.enable_kubernetes_resources ? 1 : 0

  source            = "./modules/jenkins"
  common_tags       = local.common_tags
  cluster_name      = module.eks[0].eks_cluster_name
  oidc_provider_arn = module.eks[0].oidc_provider_arn
  oidc_provider_url = module.eks[0].oidc_provider_url
  github_pat        = var.github_pat
  github_user       = var.github_user
  github_repo_url   = var.github_repo_url

  # ECR Configuration
  ecr_repository_url    = module.ecr[0].repository_url
  ecr_repository_name   = var.ecr_repository_name
  ecr_registry_endpoint = regex("^([^/]+)", module.ecr[0].repository_url)[0]

  # Depends on EKS, ECR, StorageClass, and ALB Controller (for ingress)
  depends_on = [
    module.eks,
    module.ecr,
    kubernetes_storage_class_v1.ebs_sc,
    module.aws_load_balancer_controller
  ]
}

# --------------------------------------------------------------------------------------
# AWS Load Balancer Controller Module
module "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller && var.enable_eks && var.enable_vpc && var.enable_kubernetes_resources ? 1 : 0

  source = "./modules/aws_load_balancer_controller"

  cluster_name                               = module.eks[0].eks_cluster_name
  oidc_provider_arn                          = module.eks[0].oidc_provider_arn
  oidc_provider_url                          = module.eks[0].oidc_provider_url
  vpc_id                                     = module.vpc[0].vpc_id
  aws_load_balancer_controller_chart_version = "1.8.1"
  common_tags                                = local.common_tags

  depends_on = [module.eks]
}

# --------------------------------------------------------------------------------------
# Argo CD Module
module "argo_cd" {
  count = var.enable_argo_cd && var.enable_eks && var.enable_kubernetes_resources ? 1 : 0

  source                = "./modules/argo_cd"
  common_tags           = local.common_tags
  name                  = "argo-cd"
  namespace             = "argocd"
  chart_version         = "9.1.9"
  eks_cluster_endpoint  = module.eks[0].eks_cluster_endpoint
  eks_cluster_name      = module.eks[0].eks_cluster_name
  eks_node_group_status = module.eks[0].eks_node_group_status

  # Add missing variables for cleanup
  aws_region   = var.region
  cluster_name = module.eks[0].eks_cluster_name

  # AWS Load Balancer Controller dependency
  enable_aws_load_balancer_controller     = var.enable_aws_load_balancer_controller
  aws_load_balancer_controller_dependency = var.enable_aws_load_balancer_controller ? module.aws_load_balancer_controller[0].aws_load_balancer_controller_helm_release : null

  # GitHub Variables for Repository Access
  github_repo_url = var.github_repo_url
  github_user     = var.github_user
  github_pat      = var.github_pat
  github_branch   = var.github_branch

  # Explicit dependency on ALB controller to ensure webhook is ready
  depends_on = [
    module.eks,
    module.aws_load_balancer_controller
  ]
}

# --------------------------------------------------------------------------------------
# Monitoring Module
module "monitoring" {
  count = var.enable_monitoring && var.enable_eks && var.enable_kubernetes_resources ? 1 : 0

  source                  = "./modules/monitoring"
  common_tags             = local.common_tags
  namespace               = "monitoring"
  prometheus_storage_size = "10Gi"
  grafana_storage_size    = "5Gi"
  eks_cluster_endpoint    = module.eks[0].eks_cluster_endpoint

  depends_on = [module.eks, kubernetes_storage_class_v1.ebs_sc]
}
