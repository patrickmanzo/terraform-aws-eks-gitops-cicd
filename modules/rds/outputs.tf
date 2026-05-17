output "rds_endpoint" {
  description = "RDS endpoint for connecting to the database"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.standard[0].endpoint
}

output "rds_port" {
  description = "RDS port for connecting to the database"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].port : aws_db_instance.standard[0].port
}
