variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
variable "namespace" {
  description = "Kubernetes namespace for deploying Jenkins"
  type        = string
  default     = "jenkins"
}
variable "oidc_provider_arn" {
  description = "OIDC provider ARN from EKS cluster"
  type        = string
}
variable "oidc_provider_url" {
  type = string
}

variable "chart_version" {
  description = "Version of the Jenkins Helm chart"
  type        = string
  default     = "5.9.19"

}

// github credentials

variable "github_pat" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_user" {
  description = "GitHub username"
  type        = string
}

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
}

// ECR Configuration
variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "ecr_registry_endpoint" {
  description = "ECR registry endpoint"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
