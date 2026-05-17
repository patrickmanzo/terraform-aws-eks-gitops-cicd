# --------------------------------------------------------------------------------------
# Data Sources
# --------------------------------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --------------------------------------------------------------------------------------
# CloudWatch Log Group for Session Manager
# --------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "bastion_ssm" {
  count             = var.enable_session_manager ? 1 : 0
  name              = "/aws/sessionmanager/${var.name_prefix}-bastion"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-bastion-ssm-logs"
    ResourceType = "LogGroup"
    Service      = "SystemsManager"
    Purpose      = "SessionLogs"
  })
}

# --------------------------------------------------------------------------------------
# S3 Bucket for Bastion Host
# --------------------------------------------------------------------------------------
resource "aws_s3_bucket" "bastion" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_name != null ? var.s3_bucket_name : "${var.name_prefix}-bastion-${random_id.bucket_suffix[0].hex}"

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-bastion-bucket"
    ResourceType = "S3Bucket"
    Service      = "Bastion"
    Purpose      = "Management"
    Environment  = var.environment
  })
}

resource "random_id" "bucket_suffix" {
  count       = var.create_s3_bucket ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "bastion" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.bastion[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bastion" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.bastion[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bastion" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.bastion[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------------------------------------
# IAM Role for Bastion Host
# --------------------------------------------------------------------------------------
resource "aws_iam_role" "bastion" {
  name = "${var.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-bastion-role"
    ResourceType = "IAMRole"
    Service      = "Bastion"
    Purpose      = "ServiceRole"
  })
}

# Consolidated IAM policy for all bastion permissions
resource "aws_iam_role_policy" "bastion_consolidated" {
  name = "${var.name_prefix}-bastion-consolidated-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Session Manager permissions
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      # S3 bucket access
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = var.create_s3_bucket ? [
          aws_s3_bucket.bastion[0].arn,
          "${aws_s3_bucket.bastion[0].arn}/*"
        ] : ["*"]
      },
      # EKS permissions
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      # ECR permissions
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetRepositoryPolicy",
          "ecr:ListTagsForResource"
        ]
        Resource = "*"
      },
      # EC2 permissions
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRegions",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = "*"
      },
      # RDS permissions
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBClusterParameterGroups",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBClusterSnapshots",
          "rds:DescribeDBEngineVersions",
          "rds:ListTagsForResource",
          "rds:DescribeDBSecurityGroups",
          "rds:DescribeEventCategories",
          "rds:DescribeEvents",
          "rds:DescribeDBLogFiles",
          "rds:DownloadDBLogFilePortion"
        ]
        Resource = "*"
      },
      # General AWS permissions for basic operations
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-bastion-profile"
  })
}

# --------------------------------------------------------------------------------------
# Security Group for Bastion Host
# --------------------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH access (if key_name is provided)
  dynamic "ingress" {
    for_each = var.key_name != null && length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "SSH access to bastion"
    }
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-bastion-sg"
  })
}

# --------------------------------------------------------------------------------------
# Security Group Rules for Database Access
# --------------------------------------------------------------------------------------
resource "aws_security_group_rule" "rds_from_bastion" {
  count                    = var.rds_sg_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = var.rds_sg_id
  description              = "Allow bastion access to RDS"
}

# --------------------------------------------------------------------------------------
# EC2 Instance - Bastion Host
# --------------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                    = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  key_name               = var.key_name

  # Free tier optimization
  monitoring    = false
  ebs_optimized = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8 # Free tier: up to 30GB
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.common_tags, {
      Name         = "${var.name_prefix}-bastion-root-volume"
      ResourceType = "EBSVolume"
      Service      = "Bastion"
      Purpose      = "RootDisk"
    })
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    eks_cluster_name = var.eks_cluster_name
    s3_bucket_name   = var.create_s3_bucket ? aws_s3_bucket.bastion[0].bucket : ""
    region           = data.aws_region.current.name
    log_group_name   = var.enable_session_manager ? aws_cloudwatch_log_group.bastion_ssm[0].name : ""
  }))

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-bastion"
    ResourceType = "EC2Instance"
    Service      = "Bastion"
    Purpose      = "JumpServer"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------------------
# Session Manager Document
# --------------------------------------------------------------------------------------
resource "aws_ssm_document" "session_manager_prefs" {
  count           = var.enable_session_manager ? 1 : 0
  name            = "${var.name_prefix}-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences for bastion host"
    sessionType   = "Standard_Stream"
    inputs = {
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.bastion_ssm[0].name
      cloudWatchEncryptionEnabled = false
      s3BucketName                = var.create_s3_bucket ? aws_s3_bucket.bastion[0].bucket : ""
      s3EncryptionEnabled         = var.create_s3_bucket ? true : false
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-session-manager-prefs"
  })
}

resource "aws_ssm_association" "session_manager_prefs" {
  count = var.enable_session_manager ? 1 : 0
  name  = aws_ssm_document.session_manager_prefs[0].name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.bastion.id]
  }
}
