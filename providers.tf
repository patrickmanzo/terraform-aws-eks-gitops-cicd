terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Data sources for EKS authentication (only when EKS is enabled and exists)
data "aws_eks_cluster" "cluster" {
  count = var.enable_eks && var.enable_kubernetes_resources ? 1 : 0
  name  = "${var.environment}-${var.project}-eks-cluster"

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.enable_eks && var.enable_kubernetes_resources ? 1 : 0
  name  = "${var.environment}-${var.project}-eks-cluster"

  depends_on = [module.eks]
}

# Kubernetes provider - configured dynamically based on EKS cluster
# When enable_kubernetes_resources=false, provider uses null values and won't attempt connections
provider "kubernetes" {
  host                   = var.enable_eks && var.enable_kubernetes_resources ? try(data.aws_eks_cluster.cluster[0].endpoint, null) : null
  cluster_ca_certificate = var.enable_eks && var.enable_kubernetes_resources ? try(base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data), null) : null
  token                  = var.enable_eks && var.enable_kubernetes_resources ? try(data.aws_eks_cluster_auth.cluster[0].token, null) : null
}

# Helm provider - uses same authentication as kubernetes provider
provider "helm" {
  kubernetes {
    host                   = var.enable_eks && var.enable_kubernetes_resources ? try(data.aws_eks_cluster.cluster[0].endpoint, null) : null
    cluster_ca_certificate = var.enable_eks && var.enable_kubernetes_resources ? try(base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data), null) : null
    token                  = var.enable_eks && var.enable_kubernetes_resources ? try(data.aws_eks_cluster_auth.cluster[0].token, null) : null
  }
}
