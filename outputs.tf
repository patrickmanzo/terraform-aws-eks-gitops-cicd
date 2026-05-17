#-------------Backend-----------------

#output "s3_bucket_name" {
#  description = "Name of the S3 bucket for storing Terraform state files"
#  value       = module.s3_backend.s3_bucket_name
#}

#output "dynamodb_table_name" {
#  description = "Name of the DynamoDB table for state locking"
#  value       = module.s3_backend.dynamodb_table_name
#}

#-------------VPC-----------------
# VPC Outputs (useful for general network information)
output "vpc_id" {
  description = "The ID of the main VPC."
  value       = var.enable_vpc ? module.vpc[0].vpc_id : null
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = var.enable_vpc ? module.vpc[0].public_subnet_ids : null
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = var.enable_vpc ? module.vpc[0].private_subnet_ids : null
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = var.enable_vpc ? module.vpc[0].vpc_cidr_block : null
}

#output "internet_gateway_id" {
#  description = "ID of the Internet Gateway"
#  value       = module.vpc.internet_gateway_id
#}

#output "nat_gateway_ids" {
#  description = "IDs of the NAT Gateways"
#  value       = module.vpc.nat_gateway_ids
#}

#-------------ECR-----------------

output "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  value       = var.enable_ecr ? module.ecr[0].repository_url : null
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = var.enable_ecr ? module.ecr[0].repository_arn : null
}

# ECR Registry endpoint (derived from repository URL)
output "ecr_registry_endpoint" {
  description = "ECR registry endpoint (without repository name)"
  value       = var.enable_ecr ? regex("^([^/]+)", module.ecr[0].repository_url)[0] : null
}

#-------------EKS-----------------

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.enable_eks ? module.eks[0].eks_cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = var.enable_eks ? module.eks[0].eks_cluster_endpoint : null
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS Worker Nodes"
  value       = var.enable_eks ? module.eks[0].eks_node_role_arn : null
}

##-------------Jenkins-----------------

output "jenkins_release" {
  description = "Jenkins Helm release name"
  value       = var.enable_jenkins && var.enable_kubernetes_resources ? module.jenkins[0].jenkins_release_name : null
}

output "jenkins_namespace" {
  description = "Jenkins namespace"
  value       = var.enable_jenkins && var.enable_kubernetes_resources ? module.jenkins[0].jenkins_namespace : null
}

##-------------ArgoCD-----------------

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.enable_argo_cd && var.enable_kubernetes_resources ? module.argo_cd[0].namespace : null
}

##-------------Monitoring-----------------

output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = var.enable_monitoring && var.enable_kubernetes_resources ? "monitoring" : null
}

##-------------Bastion-----------------

output "bastion_instance_id" {
  description = "Bastion host instance ID"
  value       = var.enable_bastion ? module.bastion[0].instance_id : null
}

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = var.enable_bastion ? module.bastion[0].public_ip : null
}

##-------------RDS-----------------

output "rds_endpoint" {
  description = "RDS endpoint for connecting to the database"
  value       = var.enable_rds ? module.rds[0].rds_endpoint : null
  sensitive   = false
}

output "rds_port" {
  description = "RDS port for connecting to the database"
  value       = var.enable_rds ? module.rds[0].rds_port : null
  sensitive   = false
}
