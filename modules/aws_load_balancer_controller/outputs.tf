output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "aws_load_balancer_controller_service_account_name" {
  description = "Name of the AWS Load Balancer Controller service account"
  value       = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
}

output "aws_load_balancer_controller_helm_release" {
  description = "AWS Load Balancer Controller Helm release for dependencies"
  value       = helm_release.aws_load_balancer_controller
}
