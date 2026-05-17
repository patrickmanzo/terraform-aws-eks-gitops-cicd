# Ensure EKS cluster is fully ready before installing ArgoCD
resource "null_resource" "eks_cluster_ready" {
  # This resource will be recreated if any of these values change
  triggers = {
    cluster_endpoint  = var.eks_cluster_endpoint
    cluster_name      = var.eks_cluster_name
    node_group_status = var.eks_node_group_status
  }
}

# Wait for AWS Load Balancer Controller webhook to be ready (or no-op if disabled)
resource "null_resource" "wait_for_alb_controller" {
  # Always create this resource to avoid depends_on issues
  provisioner "local-exec" {
    command = var.enable_aws_load_balancer_controller ? "bash -c '${local.alb_webhook_wait_script}'" : "echo 'ℹ️ ALB Controller disabled - skipping webhook wait'"

    # Continue even if webhook check fails
    on_failure = continue
  }

  # Trigger based on ALB controller status and dependency
  triggers = {
    alb_enabled    = var.enable_aws_load_balancer_controller
    alb_dependency = var.aws_load_balancer_controller_dependency != null ? "enabled" : "disabled"
  }
}

# Local values for cleaner script management
locals {
  alb_webhook_wait_script = <<-EOT
    echo "🔄 Waiting for ALB Controller webhook..."
    for i in {1..30}; do
      if kubectl get endpoints aws-load-balancer-webhook-service -n kube-system &>/dev/null; then
        echo "✅ ALB Controller webhook ready"
        break
      else
        echo "⏳ Attempt $i/30..."
        sleep 10
      fi
      if [ $i -eq 30 ]; then
        echo "⚠️ Timeout after 5min, proceeding anyway"
        break
      fi
    done
    echo "⏳ Final 30s wait..."
    sleep 30
    echo "✅ ArgoCD can now install safely"
  EOT
}

# Create the argocd namespace first
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.namespace
  }

  depends_on = [
    null_resource.eks_cluster_ready,
    null_resource.wait_for_alb_controller
  ]
}

# WORKAROUND: Create argocd-redis secret even when Redis is disabled
# The ArgoCD Helm chart v9.x has a bug where it still references this secret
# in pod specs even when redis.enabled=false
resource "kubernetes_secret_v1" "argocd_redis" {
  metadata {
    name      = "argocd-redis"
    namespace = var.namespace
  }

  data = {
    auth = ""
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}

# Pre-destroy resource to handle finalizer cleanup and ALB deletion properly
resource "null_resource" "argo_cleanup" {
  # This will run before destruction to ensure clean removal
  triggers = {
    # Trigger cleanup when ArgoCD components are destroyed
    argo_cd_name   = helm_release.argo_cd.name
    argo_apps_name = helm_release.argo_apps.name
  }

  # Use local-exec to handle any necessary pre-destroy cleanup
  # This runs BEFORE Helm tries to delete resources
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🧹 ArgoCD Pre-Destroy Cleanup Starting..."

      # Check if kubectl is available and cluster is accessible
      if kubectl cluster-info &>/dev/null; then
        echo "✅ Cluster accessible - performing safe cleanup"

        # CRITICAL: Delete all Ingresses FIRST to trigger ALB Controller cleanup
        # This must happen while ALB Controller is still running
        echo "🔧 Deleting all Ingress resources to trigger ALB cleanup..."

        # Delete ingresses in all namespaces (this triggers ALB Controller to delete ALBs)
        for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
          echo "  Checking namespace: $ns"
          kubectl delete ingress --all -n "$ns" --timeout=60s 2>/dev/null || true
        done

        # Wait for ALBs to be deleted by the controller
        echo "⏳ Waiting 90s for ALB Controller to delete Load Balancers..."
        sleep 90

        # Remove finalizers from ArgoCD Applications
        echo "🔧 Removing finalizers from ArgoCD Applications (if any)..."
        kubectl get applications -n argocd -o name 2>/dev/null | while read app; do
          if [ -n "$app" ]; then
            kubectl patch "$app" -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
          fi
        done

        echo "🔧 Removing finalizers from ArgoCD ApplicationSets (if any)..."
        kubectl get applicationsets -n argocd -o name 2>/dev/null | while read appset; do
          if [ -n "$appset" ]; then
            kubectl patch "$appset" -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
          fi
        done

        echo "✅ Cleanup completed - Helm can now proceed safely"
      else
        echo "⚠️ Cluster not accessible - cleanup will be handled by Terraform timeout"
      fi

      echo "🏁 ArgoCD Pre-Destroy Cleanup Completed"
    EOT

    # Continue even if some commands fail
    on_failure = continue
  }

  # This depends on both Helm releases being present
  depends_on = [
    helm_release.argo_cd,
    helm_release.argo_apps
  ]
}

resource "helm_release" "argo_cd" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  # Enhanced settings for proper lifecycle management
  timeout         = 900 # 15 minutes for ArgoCD installation
  atomic          = true
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true

  # Critical: Disable resource validation during delete to prevent conflicts
  disable_webhooks = true
  create_namespace = false # We create namespace manually with the redis secret

  # Redis configuration - disable completely (not needed for lab/dev)
  set {
    name  = "redis.enabled"
    value = "false"
  }

  set {
    name  = "redis-ha.enabled"
    value = "false"
  }

  set {
    name  = "externalRedis.enabled"
    value = "false"
  }

  # Server configuration - run in insecure mode (ALB handles TLS)
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # IMPORTANT: Don't set basehref/rootpath - causes redirect loops with ALB
  set {
    name  = "configs.params.server\\.basehref"
    value = ""
  }

  set {
    name  = "configs.params.server\\.rootpath"
    value = ""
  }

  # Disable the default ingress from helm chart (we create our own)
  set {
    name  = "server.ingress.enabled"
    value = "false"
  }

  values = [
    templatefile("${path.module}/values.yaml", {
      admin_password = "$2a$10$8YJR5gDoPPxlIAhnKrqDO.hcoJPiD44rMRwt4XxpV/m2ObWITUrQu"
    })
  ]

  # Add lifecycle management to handle CRDs properly
  lifecycle {
    ignore_changes = [values]
  }

  # Ensure namespace and redis secret exist before installing
  depends_on = [
    null_resource.eks_cluster_ready,
    null_resource.wait_for_alb_controller,
    kubernetes_namespace_v1.argocd,
    kubernetes_secret_v1.argocd_redis
  ]
}

# Create ingress separately to avoid helm chart's hostname defaults
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-ingress"
    namespace = var.namespace
    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80}]"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${var.name}-argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argo_cd]
}

resource "helm_release" "argo_apps" {
  name             = "${var.name}-apps"
  chart            = "${path.module}/charts"
  namespace        = var.namespace
  create_namespace = false

  # Enhanced timeout and cleanup settings for proper destroy
  timeout         = 1200 # 20 minutes for complex applications with finalizer cleanup
  atomic          = true
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true
  reuse_values    = false # Don't reuse values to ensure clean state
  recreate_pods   = false

  # Critical: Disable resource validation during delete to prevent conflicts
  # This allows Helm to delete resources even if they've been manually modified
  disable_webhooks = true

  # Add lifecycle management to handle finalizers properly
  lifecycle {
    # Prevent destroy conflicts by ignoring some resource states
    ignore_changes = [
      # Ignore changes to these fields that might be modified by ArgoCD itself
      values,
      version
    ]
  }

  values = [
    templatefile("${path.module}/charts/values.yaml", {
      github_repo_url = var.github_repo_url
      github_user     = var.github_user
      github_pat      = var.github_pat
      github_branch   = var.github_branch
    })
  ]

  depends_on = [
    helm_release.argo_cd,
    null_resource.eks_cluster_ready,
    null_resource.wait_for_alb_controller
  ]
}
