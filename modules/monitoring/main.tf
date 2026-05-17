# Note: EBS StorageClass "ebs-sc" is created at root level in modules.tf
# The dependency is handled there via depends_on in the module call

resource "helm_release" "kube-prometheus-stack" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "75.10.0"
  create_namespace = true
  timeout          = 600
  wait             = true

  values = [
    file("${path.module}/values.yaml")
  ]
}
