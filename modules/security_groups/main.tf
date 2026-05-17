resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Security group for EC2 nodes"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = lookup(ingress.value, "description", null)
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = lookup(egress.value, "description", null)
    }
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-ec2-sg"
    ResourceType = "SecurityGroup"
    Service      = "EC2"
    Purpose      = "Instance-Access"
  })
}

resource "aws_security_group" "eks" {
  name        = "${var.name_prefix}-eks-sg"
  description = "Security group for EKS nodes"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.eks_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = lookup(ingress.value, "description", null)
    }
  }

  dynamic "egress" {
    for_each = var.eks_egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = lookup(egress.value, "description", null)
    }
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-eks-sg"
    ResourceType = "SecurityGroup"
    Service      = "EKS"
    Purpose      = "Node-Access"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.rds_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = lookup(ingress.value, "description", null)
    }
  }

  dynamic "egress" {
    for_each = var.rds_egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = lookup(egress.value, "description", null)
    }
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-rds-sg"
    ResourceType = "SecurityGroup"
    Service      = "RDS"
    Purpose      = "Database-Access"
  })
}

resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.lambda_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = lookup(ingress.value, "description", null)
    }
  }

  dynamic "egress" {
    for_each = var.lambda_egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = lookup(egress.value, "description", null)
    }
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-lambda-sg"
    ResourceType = "SecurityGroup"
    Service      = "Lambda"
    Purpose      = "Function-Access"
  })
}
