output "namespace" {
  description = "ArgoCD namespace"
  value       = var.namespace
}

output "release_name" {
  description = "ArgoCD Helm release name"
  value       = helm_release.argo_cd.name
}

output "admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "port_forward_command" {
  description = "Command to port-forward ArgoCD UI"
  value       = "kubectl port-forward svc/${var.name}-argocd-server -n ${var.namespace} 8080:80"
}

output "ingress_hostname" {
  description = "ArgoCD ingress hostname (ALB DNS)"
  value       = try(kubernetes_ingress_v1.argocd.status[0].load_balancer[0].ingress[0].hostname, "pending")
}
