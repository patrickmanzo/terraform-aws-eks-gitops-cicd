variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  type        = string
  description = "IMMUTABLE prevents changes to existing tags; MUTABLE allows overwriting."
  default     = "MUTABLE"
}

variable "force_delete" {
  type        = bool
  description = "If true, deleting the repository will also delete all images inside it."
  default     = true
}

variable "repository_policy" {
  type        = string
  description = "JSON policy for the repository."
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
