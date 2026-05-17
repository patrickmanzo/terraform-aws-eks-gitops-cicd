resource "aws_lb" "this" {
  name                       = var.name
  internal                   = var.internal
  load_balancer_type         = "network"
  subnets                    = var.subnet_ids
  enable_deletion_protection = var.enable_deletion_protection

  dynamic "access_logs" {
    for_each = var.access_logs.enabled ? [1] : []
    content {
      bucket  = var.access_logs.bucket
      enabled = var.access_logs.enabled
      prefix  = var.access_logs.prefix
    }
  }

  tags = merge(var.common_tags, {
    Name         = var.name
    ResourceType = "LoadBalancer"
    Service      = "ELB"
    Purpose      = "TrafficDistribution"
    Internal     = var.internal ? "true" : "false"
  })
}

resource "aws_lb_target_group" "this" {
  name        = var.target_group_name
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    enabled             = var.health_check_enabled
    interval            = var.health_check_interval
    protocol            = var.health_check_protocol
    port                = var.health_check_port
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    matcher             = var.health_check_matcher
  }

  tags = merge(var.common_tags, {
    Name         = var.target_group_name
    ResourceType = "TargetGroup"
    Service      = "ELB"
    Purpose      = "TargetManagement"
  })
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
