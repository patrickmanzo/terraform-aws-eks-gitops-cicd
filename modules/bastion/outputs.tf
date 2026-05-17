output "bastion_instance_id" {
  description = "ID of the bastion host instance"
  value       = aws_instance.bastion.id
}

output "bastion_instance_arn" {
  description = "ARN of the bastion host instance"
  value       = aws_instance.bastion.arn
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion host"
  value       = aws_instance.bastion.private_ip
}

output "bastion_security_group_id" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "bastion_iam_role_arn" {
  description = "IAM role ARN of the bastion host"
  value       = aws_iam_role.bastion.arn
}

output "bastion_iam_role_name" {
  description = "IAM role name of the bastion host"
  value       = aws_iam_role.bastion.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created for bastion host"
  value       = var.create_s3_bucket ? aws_s3_bucket.bastion[0].bucket : null
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket created for bastion host"
  value       = var.create_s3_bucket ? aws_s3_bucket.bastion[0].arn : null
}

output "session_manager_document_name" {
  description = "Name of the Session Manager document"
  value       = var.enable_session_manager ? aws_ssm_document.session_manager_prefs[0].name : null
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for Session Manager"
  value       = var.enable_session_manager ? aws_cloudwatch_log_group.bastion_ssm[0].name : null
}

# Connection information
output "ssh_connection_command" {
  description = "SSH connection command (if key_name is provided)"
  value       = var.key_name != null ? "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.bastion.public_ip}" : "SSH key not configured"
}

output "session_manager_connection_command" {
  description = "AWS Session Manager connection command"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id}"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl on bastion"
  value       = var.eks_cluster_name != "" ? "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${var.eks_cluster_name}" : "EKS cluster name not provided"
}

# Helper commands for ECR, EC2, and RDS
output "ecr_list_repos_command" {
  description = "Command to list ECR repositories from bastion"
  value       = "~/ecr-helper.sh repos"
}

output "ec2_list_command" {
  description = "Command to list EC2 instances from bastion"
  value       = "~/ec2-helper.sh list"
}

output "rds_list_command" {
  description = "Command to list RDS instances from bastion"
  value       = "~/rds-helper.sh instances"
}

output "rds_clusters_command" {
  description = "Command to list RDS clusters from bastion"
  value       = "~/rds-helper.sh clusters"
}

output "available_helper_scripts" {
  description = "Available helper scripts on bastion host"
  value = [
    "~/setup-eks.sh - Configure kubectl for EKS",
    "~/connect-db.sh - Database connection examples",
    "~/ecr-helper.sh - ECR repository management",
    "~/ec2-helper.sh - EC2 instance management",
    "~/rds-helper.sh - RDS database management"
  ]
}
