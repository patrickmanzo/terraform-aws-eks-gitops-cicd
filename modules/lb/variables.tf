variable "name" {
  description = "The name of the Network Load Balancer"
  type        = string
}

variable "internal" {
  description = "Whether the NLB is internal"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "A list of subnet IDs to attach to the NLB"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "If true, deletion protection will be enabled"
  type        = bool
  default     = false
}

variable "access_logs" {
  description = "Configuration block for access logs"
  type = object({
    enabled = bool
    bucket  = string
    prefix  = string
  })
  default = {
    enabled = false
    bucket  = ""
    prefix  = ""
  }
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "target_group_name" {
  description = "Name for the target group"
  type        = string
}

variable "target_group_port" {
  description = "Port for the target group"
  type        = number
}

variable "target_group_protocol" {
  description = "Protocol for the target group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "target_type" {
  description = "Target type for the target group"
  type        = string
  default     = "instance"
}

variable "health_check_enabled" {
  description = "Whether health checks are enabled"
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "Interval for health checks"
  type        = number
  default     = 30
}

variable "health_check_protocol" {
  description = "Protocol for health checks"
  type        = string
  default     = "TCP"
}

variable "health_check_port" {
  description = "Port for health checks"
  type        = string
  default     = "traffic-port"
}

variable "health_check_healthy_threshold" {
  description = "Healthy threshold for health checks"
  type        = number
  default     = 3
}

variable "health_check_unhealthy_threshold" {
  description = "Unhealthy threshold for health checks"
  type        = number
  default     = 3
}

variable "health_check_timeout" {
  description = "Timeout for health checks"
  type        = number
  default     = 10
}

variable "health_check_path" {
  description = "Path for health checks (for HTTP/HTTPS)"
  type        = string
  default     = ""
}

variable "health_check_matcher" {
  description = "Matcher for health checks (for HTTP/HTTPS)"
  type        = string
  default     = ""
}

variable "listener_port" {
  description = "Port for the listener"
  type        = number
}

variable "listener_protocol" {
  description = "Protocol for the listener"
  type        = string
}
