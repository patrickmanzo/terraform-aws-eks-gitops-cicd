output "ec2_sg_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "eks_sg_id" {
  description = "ID of the EKS security group"
  value       = aws_security_group.eks.id
}

output "rds_sg_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "lambda_sg_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda.id
}
