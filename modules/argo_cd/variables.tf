variable "name" {
  description = "Name for ArgoCD release"
  type        = string
  default     = "argo-cd"
}

variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.1.9"
}

variable "eks_cluster_endpoint" {
  description = "EKS cluster endpoint for dependency"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name for dependency"
  type        = string
}

variable "eks_node_group_status" {
  description = "EKS node group status for dependency"
  type        = string
}

variable "aws_region" {
  description = "AWS region for EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}

# GitHub Variables for ArgoCD Repository Configuration
variable "github_repo_url" {
  description = "GitHub repository URL for ArgoCD applications"
  type        = string
}

variable "github_user" {
  description = "GitHub username for repository access"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for repository access"
  type        = string
  sensitive   = true
}

variable "github_branch" {
  description = "GitHub branch to deploy from"
  type        = string
  default     = "main"
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether AWS Load Balancer Controller is enabled (affects dependencies)"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_dependency" {
  description = "Dependency on AWS Load Balancer Controller (pass the helm release)"
  type        = any
  default     = null
}
