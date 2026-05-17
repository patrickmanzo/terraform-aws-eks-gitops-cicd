# Data source to fetch the current AWS Partition for ARN construction
data "aws_partition" "current" {}

# Data source to fetch the current AWS Account ID and ARN
data "aws_caller_identity" "current" {}

# Data source to get the default EBS encryption KMS key
data "aws_ebs_default_kms_key" "current" {}

# Data source to get the KMS key details for EBS encryption
data "aws_kms_key" "ebs" {
  key_id = data.aws_ebs_default_kms_key.current.key_arn
}

# Local to determine the Kubernetes version (use provided or latest)
locals {
  kubernetes_version = var.kubernetes_version != null ? var.kubernetes_version : "1.32"
}

# Data source to get the latest EKS-optimized AMI for the specified Kubernetes version
# and AMI type (e.g., AL2023_x86_64, BOTTLEROCKET_x86_64)
# We'll use this in the launch template if a specific AMI is not provided
data "aws_ami" "eks_node_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    values = [
      var.node_group_ami_type == "AL2_x86_64" ? "amazon-eks-node-${local.kubernetes_version}-v*" :
      var.node_group_ami_type == "AL2023_x86_64_STANDARD" ? "amazon-eks-node-al2023-x86_64-standard-${local.kubernetes_version}-v*" :
      var.node_group_ami_type == "BOTTLEROCKET_x86_64" ? "bottlerocket-aws-k8s-${local.kubernetes_version}-x86_64-*" :
      var.node_group_ami_type == "BOTTLEROCKET_ARM_64" ? "bottlerocket-aws-k8s-${local.kubernetes_version}-arm64-*" :
      "amazon-eks-node-${local.kubernetes_version}-v*"
    ]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  # filter to avoid GPU AMIs if not intended
  filter {
    name   = "description"
    values = ["*EKS*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --------------------------------------------------------------------------------------
# 1. IAM Role for EKS Cluster Control Plane
# --------------------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  name = "${var.name_prefix}-eks-cluster-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-cluster-iam-role"
    ResourceType = "IAMRole"
    Service      = "EKS"
    Purpose      = "ClusterServiceRole"
  })
}

# Attach IAM Policies to EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# --------------------------------------------------------------------------------------
# CloudWatch Log Group for EKS Cluster Logs
# Note: AWS EKS automatically creates this log group when cluster logging is enabled.
# If you get ResourceAlreadyExistsException, either:
# 1. Import it: terraform import module.eks.aws_cloudwatch_log_group.eks_cluster /aws/eks/dev-finance-eks-cluster/cluster
# 2. Or comment out this resource and let AWS manage it entirely
# --------------------------------------------------------------------------------------
# resource "aws_cloudwatch_log_group" "eks_cluster" {
#   name              = "/aws/eks/${var.name_prefix}-eks-cluster/cluster"
#   retention_in_days = var.cluster_log_retention_days
#   kms_key_id        = length(var.cluster_encryption_config) > 0 ? var.cluster_encryption_config[0].provider_key_arn : null
#
#   # Use lifecycle rules to handle AWS auto-creation gracefully
#   lifecycle {
#     # Prevent destruction to avoid data loss
#     prevent_destroy = false
#     # Ignore changes that AWS might make
#     ignore_changes = [
#       name,           # AWS might recreate with different naming
#       log_group_class # AWS manages this
#     ]
#   }
#
#   tags = merge(var.common_tags, {
#     Name = "${var.name_prefix}-eks-cluster-logs"
#     ResourceType = "LogGroup"
#     Service = "EKS"
#     Purpose = "ClusterLogging"
#   })

## --------------------------------------------------------------------------------------
# 2. EKS Cluster
# --------------------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = local.kubernetes_version

  vpc_config {
    subnet_ids = var.private_subnet_ids
    # This remains, as the cluster depends on the existence of the SG ID
    security_group_ids = [aws_security_group.eks_control_plane_sg.id]

    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_endpoint_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  # Optional: Cluster encryption configuration
  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config
    content {
      provider {
        key_arn = encryption_config.value.provider_key_arn
      }
      resources = encryption_config.value.resources
    }
  }

  # Optional: Service IPv4 CIDR
  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
    ip_family         = var.cluster_ip_family
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-cluster"
    ResourceType = "EKSCluster"
    Service      = "EKS"
    Purpose      = "ContainerOrchestration"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

#resource "kubernetes_config_map" "aws_auth" {
#  count = var.manage_aws_auth_configmap ? 1 : 0
#
#  metadata {
#    name      = "aws-auth"
#    namespace = "kube-system"
#  }
#
#  data = {
#    mapUsers = yamlencode([
#      {
#        userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-access"
#        username = "terraform-access"
#        groups   = ["system:masters"]
#      }
#    ])
#  }
#
#  depends_on = [
#    aws_eks_cluster.this,
#  ]
#}

# --------------------------------------------------------------------------------------
# Security Group for EKS Control Plane
# --------------------------------------------------------------------------------------
resource "aws_security_group" "eks_control_plane_sg" {
  name_prefix = "${var.name_prefix}-eks-cp-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EKS control plane network interfaces"

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-control-plane-sg"
    ResourceType = "SecurityGroup"
    Service      = "EKS"
    Purpose      = "ControlPlaneNetworking"
  })
}

# --------------------------------------------------------------------------------------
# IAM Role
# --------------------------------------------------------------------------------------

# IAM Role for EKS administrator
resource "aws_iam_role" "eks_admin" {
  name = "${var.name_prefix}-eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" # Use the correct data source
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-admin-role"
    ResourceType = "IAMRole"
    Service      = "EKS"
    Purpose      = "AdminAccess"
  })
}

# Attach AdministratorAccess policy (for lab purposes)
resource "aws_iam_role_policy_attachment" "eks_admin_policy_attach" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

# --------------------------------------------------------------------------------------
# Security Group for EKS Node Group
# --------------------------------------------------------------------------------------
resource "aws_security_group" "eks_node_group_sg" {
  name_prefix = "${var.name_prefix}-eks-node-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EKS worker nodes"

  tags = merge(var.common_tags, {
    Name                                                 = "${var.name_prefix}-eks-node-sg"
    ResourceType                                         = "SecurityGroup"
    Service                                              = "EKS"
    Purpose                                              = "NodeNetworking"
    "kubernetes.io/cluster/${aws_eks_cluster.this.name}" = "owned"
  })
}

# --------------------------------------------------------------------------------------
# Security Group Rules for EKS Control Plane
# --------------------------------------------------------------------------------------
resource "aws_security_group_rule" "cp_ingress_443_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_control_plane_sg.id
  source_security_group_id = aws_security_group.eks_node_group_sg.id
  description              = "Allow nodes to call Kubernetes API"
}

resource "aws_security_group_rule" "cp_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_control_plane_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound from control plane"
}

# --------------------------------------------------------------------------------------
# Security Group Rules for EKS Node Group
# --------------------------------------------------------------------------------------
resource "aws_security_group_rule" "eks_node_ingress_cp_9443" {
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_group_sg.id
  source_security_group_id = aws_security_group.eks_control_plane_sg.id
  description              = "Allow control plane to Node port 9443"
}

resource "aws_security_group_rule" "eks_node_ingress_cp_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_group_sg.id
  source_security_group_id = aws_security_group.eks_control_plane_sg.id
  description              = "Allow control plane to Node port 443"
}

resource "aws_security_group_rule" "eks_node_ingress_self_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_group_sg.id
  self              = true
  description       = "Allow all traffic within the node group"
}

resource "aws_security_group_rule" "eks_node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_group_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Worker Nodes"
}

# Add any other necessary rules, like for your bastion host or CI/CD access.
resource "aws_security_group_rule" "eks_node_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_group_sg.id
  cidr_blocks       = [var.vpc_cidr_block] # Adjust to your specific needs
  description       = "Allow SSH (DEBUG: RESTRICT THIS!)"
}

# --------------------------------------------------------------------------------------
# 3. IAM Role for EKS Worker Nodes
# --------------------------------------------------------------------------------------
resource "aws_iam_role" "eks_node_group" {
  name = "${var.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-node-role"
    ResourceType = "IAMRole"
    Service      = "EKS"
    Purpose      = "NodeServiceRole"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# --------------------------------------------------------------------------------------
# 4. Launch Template for Managed Node Groups (for IMDSv2, EBS customization)
# --------------------------------------------------------------------------------------
resource "aws_launch_template" "eks_node_template" {
  name_prefix = "${var.name_prefix}-eks-node-lt"

  # Instance type is now defined in the node group, not here
  # instance_type = var.node_group_instance_types[0]

  # Ensure IMDSv2 is enforced
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Forces IMDSv2
    http_put_response_hop_limit = 2          # Recommended for pods to access IMDSv2 through the node
  }

  # Root EBS volume customization
  block_device_mappings {
    device_name = "/dev/xvda" # For AL2/AL2023. May vary for Bottlerocket or Windows
    ebs {
      volume_size           = var.node_group_disk_size
      volume_type           = var.node_group_volume_type # gp3 is generally recommended for cost/performance
      encrypted             = true                       # Always encrypt EBS volumes
      kms_key_id            = data.aws_kms_key.ebs.arn   # Use AWS default EBS encryption key
      iops                  = var.node_group_iops
      throughput            = var.node_group_throughput
      delete_on_termination = true
    }
  }

  # Key pair for SSH access (optional, if you enable SSH for troubleshooting)
  key_name = var.ssh_key_name

  # Security groups will be managed by the EKS node group directly
  # network_interfaces {
  #   security_groups = [
  #     aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  #     aws_security_group.eks_node_group_sg.id
  #   ]
  # }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      {
        "Name" = "${var.name_prefix}-eks-cluster-node"
      }
    )
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-node-lt"
    ResourceType = "LaunchTemplate"
    Service      = "EKS"
    Purpose      = "NodeConfiguration"
  })
}

# Instance Profile for the EKS Node Group IAM Role
#resource "aws_iam_instance_profile" "eks_node_instance_profile" {
#  name = "${var.name_prefix}-eks-node-profile"
#  role = aws_iam_role.eks_node_group.name
#
#  tags = merge(var.common_tags, {
#    Name = "${var.name_prefix}-eks-node-profile"
#  })
#}

# --------------------------------------------------------------------------------------
# 5. EKS Managed Node Group
# --------------------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.private_subnet_ids # Deploy nodes in private subnets

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  # Specify instance types (can be multiple for spot diversity)
  instance_types = var.node_group_instance_types

  # Enable spot instances
  capacity_type = var.node_group_capacity_type

  # Associate with the custom Launch Template for IMDSv2 and other settings
  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = aws_launch_template.eks_node_template.latest_version
  }

  # Use the specified AMI Type (AL2, AL2023, BOTTLEROCKET)
  ami_type = var.node_group_ami_type

  # Kubernetes labels
  labels = var.node_group_labels

  # Kubernetes taints
  dynamic "taint" {
    for_each = var.node_group_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Remote access configuration for SSH (optional)
  dynamic "remote_access" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.eks_node_group_sg.id]
    }
  }

  # Update strategy (useful for production upgrades)
  update_config {
    max_unavailable            = var.node_group_max_unavailable_percentage == null ? var.node_group_max_unavailable : null
    max_unavailable_percentage = var.node_group_max_unavailable_percentage
  }

  # Node group tags for EKS integration
  tags = merge(var.common_tags, {
    Name                                                 = "${var.name_prefix}-nodegroup"
    ResourceType                                         = "EKSNodeGroup"
    Service                                              = "EKS"
    Purpose                                              = "WorkerNodes"
    "kubernetes.io/cluster/${aws_eks_cluster.this.name}" = "owned"
    "eks:cluster-name"                                   = aws_eks_cluster.this.name
    "node-type"                                          = "worker"
    "capacity-type"                                      = var.node_group_capacity_type
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only_policy,
    aws_eks_cluster.this,
  ]
}

# --------------------------------------------------------------------------------------
# 6. EKS Add-ons (Managed by EKS)
# --------------------------------------------------------------------------------------
# Note: EKS typically installs default versions of these.
# Using aws_eks_addon ensures they are managed by EKS and can be updated via EKS API.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = var.vpc_cni_version
  # Replace resolve_conflicts
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_cluster.this]

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-vpc-cni"
    ResourceType = "EKSAddon"
    Service      = "EKS"
    Purpose      = "CNI"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = var.coredns_version
  # Replace resolve_conflicts
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-coredns"
    ResourceType = "EKSAddon"
    Service      = "EKS"
    Purpose      = "DNS"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_version
  # Replace resolve_conflicts
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  #depends_on                  = [aws_eks_cluster.this]

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-kube-proxy"
    ResourceType = "EKSAddon"
    Service      = "EKS"
    Purpose      = "Proxy"
  })
}

#resource "aws_eks_addon" "cloudwatch" {
#  cluster_name = aws_eks_cluster.this.name
#  addon_name   = "aws-cloudwatch"
#  # Replace resolve_conflicts
#  resolve_conflicts_on_create = "OVERWRITE"
#  resolve_conflicts_on_update = "OVERWRITE"
#  depends_on                  = [aws_eks_cluster.this]
#
#  tags = var.common_tags
#}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  service_account_role_arn    = aws_iam_role.ebs_csi_irsa_role.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]

  tags = var.common_tags
}

# --------------------------------------------------------------------------------------
# EKS Addon - cert-manager (Community Addon)
# --------------------------------------------------------------------------------------
resource "aws_eks_addon" "cert_manager" {
  count         = var.enable_cert_manager ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "cert-manager"
  addon_version = var.cert_manager_addon_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-cert-manager"
    ResourceType = "EKSAddon"
    Service      = "EKS"
    Purpose      = "CertificateManagement"
  })
}

#resource "kubernetes_storage_class" "gp3" {
#  metadata {
#    name = "gp3"
#  }
#
#  storage_provisioner    = "ebs.csi.aws.com"
#  reclaim_policy        = "Delete"
#  volume_binding_mode   = "WaitForFirstConsumer"
#  allow_volume_expansion = true
#
#  parameters = {
#    type   = "gp3"
#    fsType = "ext4"
#  }
#
#  depends_on = [aws_eks_addon.ebs_csi_driver]
#}

# --------------------------------------------------------------------------------------
# IAM Role for EBS CSI Driver (for IRSA)
# --------------------------------------------------------------------------------------
resource "aws_iam_role" "ebs_csi_irsa_role" {
  name = "${var.name_prefix}-ebs-csi-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.this.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_irsa_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_irsa_role.name
}

# --------------------------------------------------------------------------------------
# 7. IAM OIDC Provider for IRSA (IAM Roles for Service Accounts)
# --------------------------------------------------------------------------------------
# This allows Kubernetes service accounts to assume AWS IAM roles directly,
# enabling fine-grained, secure permissions for your pods.

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list = ["sts.amazonaws.com"]
  # Use the thumbprint from the tls_certificate data source
  thumbprint_list = [data.tls_certificate.eks_cluster_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = var.common_tags

  depends_on = [aws_eks_cluster.this] # Ensure cluster is created before OIDC provider
}

# Data source to get the thumbprint for the OIDC provider
# This is usually a static value for the specific public CA that signs the OIDC issuer URL
# For localstack, this may not be available or might need special handling.
# For real AWS, it's typically fetched dynamically or is well-known.

# Data source to get the thumbprint for the OIDC provider
# This is derived from the EKS cluster's OIDC issuer URL.
data "tls_certificate" "eks_cluster_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
