output "namespace" {
  description = "Monitoring namespace"
  value       = var.namespace
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = "admin123"
  sensitive   = true
}

output "prometheus_port_forward_command" {
  description = "Command to port-forward Prometheus UI"
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus -n ${var.namespace} 9090:9090"
}

output "grafana_port_forward_command" {
  description = "Command to port-forward Grafana UI"
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana -n ${var.namespace} 3000:80"
}

output "alertmanager_port_forward_command" {
  description = "Command to port-forward Alertmanager UI"
  value       = "kubectl port-forward svc/kube-prometheus-stack-alertmanager -n ${var.namespace} 9093:9093"
}
