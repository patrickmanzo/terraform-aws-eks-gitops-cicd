# --------------------------------------------------------------------------------------
# Specific variables
locals {
  project     = var.project
  environment = var.environment
  account_id  = var.account_id
  region      = var.region
  name_prefix = "${local.environment}-${local.project}"

  # Common tags applied to all resources
  common_tags = {
    Project       = local.project
    Environment   = local.environment
    ManagedBy     = "Terraform"
    CreatedBy     = "DevOpsTeam"
    Owner         = "ApplicationTeam"
    CostCenter    = "DEV-APP-XYZ"
    SecurityLevel = var.security_level
    AccountID     = local.account_id
    Company       = "YourCompanyName"
    Region        = local.region
  }

  # Computed naming conventions for consistency
  cluster_name = "${local.name_prefix}-eks-cluster"
  vpc_name     = "${local.name_prefix}-vpc"

  # Security and networking
  allowed_cidr_blocks = ["0.0.0.0/0"] # Restrict this in production!

  # Storage configurations
  ebs_storage_class = "gp3"
  backup_retention  = 1

  # Monitoring and logging
  log_retention_days = 7

  # Feature flags for optional components
  enable_monitoring     = true
  enable_argo_cd        = true
  enable_bastion        = false
  enable_rds_encryption = false

  # Resource limits for cost control
  max_node_count = 3
  min_node_count = 1
}

resource "aws_sns_topic" "billing_alerts" {
  name = "billing-alerts"

  tags = merge(local.common_tags, {
    Name         = "billing-alerts"
    ResourceType = "SNS"
    Service      = "Messaging"
    Purpose      = "BillingAlerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = "lucasaalves11@outlook.com"
}

resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "Monthly AWS Billing Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "21600" # 6 hours
  statistic           = "Maximum"
  threshold           = "10" # Set your threshold in USD
  alarm_description   = "Alarm when AWS estimated charges exceed $10"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.billing_alerts.arn]
  dimensions = {
    Currency = "USD"
  }
}
