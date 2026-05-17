variable "vpc_id" {
  description = "VPC ID where the bastion host will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the bastion host"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC for security group rules"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for the bastion host (if null, will use latest Amazon Linux 2023)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro" # Free tier eligible
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access (optional)"
  type        = string
  default     = null
}

variable "enable_session_manager" {
  description = "Enable AWS Systems Manager Session Manager"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access bastion via SSH (if key_name is provided)"
  type        = list(string)
  default     = []
}

variable "create_s3_bucket" {
  description = "Create S3 bucket for bastion host logs and scripts"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Name for the S3 bucket (if null, will be auto-generated)"
  type        = string
  default     = null
}

variable "eks_cluster_name" {
  description = "EKS cluster name for kubectl access"
  type        = string
  default     = ""
}

variable "rds_sg_id" {
  description = "RDS security group ID to allow access from bastion"
  type        = string
  default     = ""
}

variable "eks_sg_id" {
  description = "EKS security group ID to allow access from bastion"
  type        = string
  default     = ""
}
