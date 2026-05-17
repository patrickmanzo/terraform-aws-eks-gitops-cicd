variable "vpc_id" {
  description = "VPC ID for the security groups"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for naming security groups"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all security groups"
  type        = map(string)
  default     = {}
}

# EC2 Security Group
variable "ingress_rules" {
  description = "List of ingress rules for EC2 SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress rules for EC2 SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

# EKS Security Group
variable "eks_ingress" {
  description = "List of ingress rules for EKS SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

variable "eks_egress" {
  description = "List of egress rules for EKS SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

# RDS Security Group
variable "rds_ingress" {
  description = "List of ingress rules for RDS SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

variable "rds_egress" {
  description = "List of egress rules for RDS SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

# Lambda Security Group
variable "lambda_ingress" {
  description = "List of ingress rules for Lambda SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

variable "lambda_egress" {
  description = "List of egress rules for Lambda SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}
