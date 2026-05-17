variable "region" {
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block of the VPC (needed for Control Plane SG ingress)."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for the EKS worker nodes and cluster ENIs."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "A list of public subnet IDs (optional, mainly for Load Balancers or public facing services)."
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster. Set to null to use latest available version."
  type        = string
  default     = null # Use latest available version when null
}

variable "cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
}
variable "node_group_instance_types" {
  description = "List of instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t3.xlarge"] # Smaller, more reliable instances
}

variable "node_group_min_size" {
  description = "Minimum size of the node group."
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum size of the node group."
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired size of the node group."
  type        = number
  default     = 4
}

variable "node_group_ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS node group."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_group_ami_id" {
  description = "Optional: Specific AMI ID for the node group. If null, module will use EKS-optimized AMI data source."
  type        = string
  default     = null
}

variable "node_group_capacity_type" {
  description = "Type of capacity associated with the EKS node group."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_disk_size" {
  description = "Disk size (GB) for the EKS worker nodes' root volume."
  type        = number
  default     = 80
}

variable "node_group_volume_type" {
  description = "Volume type for the EKS worker nodes' root volume (e.g., gp2, gp3, io1)."
  type        = string
  default     = "gp3" # Recommended for cost/performance
}

variable "node_group_iops" {
  description = "IOPS for the EKS worker nodes' root volume. Only applicable for gp3, io1, and io2 volume types."
  type        = number
  default     = null # Use AWS default (3000 IOPS for gp3)
}

variable "node_group_throughput" {
  description = "Throughput (MiB/s) for the EKS worker nodes' root volume. Only applicable for gp3 volume type."
  type        = number
  default     = null # Use AWS default (125 MiB/s for gp3)
}


variable "enable_public_endpoint_access" {
  description = "Whether to enable public access to the EKS cluster endpoint."
  type        = bool
  default     = true # True is Recommended for production (private only)
}

variable "ssh_key_name" {
  description = "The name of the SSH Key Pair to use for EC2 instances in the node group (optional)."
  type        = string
  default     = null # Best practice: disable direct SSH or use SSM
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

variable "vpc_cni_version" {
  description = "Version of the VPC CNI addon. Set to null to use latest compatible version."
  type        = string
  default     = null # Use latest compatible version
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI Driver addon. Set to null to use latest compatible version."
  type        = string
  default     = null # Use latest compatible version
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy addon. Set to null to use latest compatible version."
  type        = string
  default     = null # Use latest compatible version
}

variable "coredns_version" {
  description = "Version of the CoreDNS addon. Set to null to use latest compatible version."
  type        = string
  default     = null # Use latest compatible version
}

#variable "cloudwatch_agent_version" {
#  description = "Version of the CloudWatch Agent addon"
#  type        = string
#  default     = "v1.0.0-eksbuild.1"
#}

variable "cert_manager_addon_version" {
  description = "Version of the cert-manager EKS addon. Set to null to use latest compatible version."
  type        = string
  default     = null # Use latest compatible version
}

variable "enable_cert_manager" {
  description = "Enable cert-manager EKS addon"
  type        = bool
  default     = true
}

variable "manage_aws_auth_configmap" {
  description = "Whether to manage the aws-auth ConfigMap."
  type        = bool
  default     = false
}

variable "aws_auth_roles" {
  description = "A list of additional IAM roles to add to the aws-auth ConfigMap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "node_group_labels" {
  description = "Key-value mapping of Kubernetes labels for the node group"
  type        = map(string)
  default     = {}
}

variable "node_group_taints" {
  description = "List of Kubernetes taints to apply to the node group"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "node_group_max_unavailable" {
  description = "Maximum number of nodes unavailable at once during a version update"
  type        = number
  default     = 1
}

variable "node_group_max_unavailable_percentage" {
  description = "Maximum percentage of nodes unavailable during a version update"
  type        = number
  default     = null
}

variable "cluster_encryption_config" {
  description = "Configuration block with encryption configuration for the cluster"
  type = list(object({
    provider_key_arn = string
    resources        = list(string)
  }))
  default = []
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Number of days to retain cluster logs"
  type        = number
  default     = 7
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Test purposes only
}

variable "cluster_service_ipv4_cidr" {
  description = "Service IPv4 CIDR for the Kubernetes cluster"
  type        = string
  default     = null
}

variable "cluster_ip_family" {
  description = "IP family used to assign Kubernetes pod and service addresses. Valid values: ipv4, ipv6"
  type        = string
  default     = "ipv4"
}
