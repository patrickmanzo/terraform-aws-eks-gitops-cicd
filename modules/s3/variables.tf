
variable "app_bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique across all AWS."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the S3 bucket will be created."
  type        = string
  default     = "us-east-1"
}

variable "force_destroy_on_delete" {
  description = "Set to true to allow Terraform to destroy the bucket even if it contains objects. Use with extreme caution in production."
  type        = bool
  default     = false # Safest default for production
}

variable "block_public_access" {
  description = "Set to true to block all public access to the bucket. HIGHLY RECOMMENDED for private buckets."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "The server-side encryption algorithm to use (e.g., AES256 or aws:kms)."
  type        = string
  default     = "AES256" # S3-managed encryption, good default
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be either 'AES256' or 'aws:kms'."
  }
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key to use if sse_algorithm is 'aws:kms'."
  type        = string
  default     = null
}

variable "enable_versioning" {
  description = "Set to true to enable versioning for the bucket. Recommended for data durability."
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Set to true to enable access logging for the bucket."
  type        = bool
  default     = true
}

variable "log_bucket_name" {
  description = "The name of the S3 bucket where access logs will be stored. Required if enable_access_logging is true."
  type        = string
  default     = null
  validation {
    condition     = var.enable_access_logging ? var.log_bucket_name != null : true
    error_message = "log_bucket_name must be specified if enable_access_logging is true."
  }
}

variable "lifecycle_rules" {
  description = "A list of lifecycle rules for the bucket (see AWS S3 lifecycle documentation for structure)."
  type = list(object({
    id     = string
    status = string
    prefix = optional(string)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration = optional(list(object({
      days = number
    })), [])
    noncurrent_version_transitions = optional(list(object({
      noncurrent_days = number
      storage_class   = string
    })), [])
    noncurrent_version_expiration = optional(list(object({
      noncurrent_days = number
    })), [])
  }))
  default = []
}

variable "environment" {
  description = "The deployment environment (e.g., dev, prod)."
  type        = string
}

variable "project" {
  description = "The project name."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names (e.g., project-environment)."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
