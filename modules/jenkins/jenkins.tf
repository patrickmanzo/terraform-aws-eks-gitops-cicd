# Note: EBS StorageClass "ebs-sc" is created by the EKS module
# This module depends on it being available

resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "kubernetes_service_account_v1" "jenkins_sa" {
  metadata {
    name      = "jenkins-sa"
    namespace = "jenkins"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_kaniko_role.arn
    }
  }
  depends_on = [kubernetes_namespace_v1.jenkins]
}

resource "aws_iam_role" "jenkins_kaniko_role" {
  name = "${var.cluster_name}-jenkins-kaniko-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:jenkins:jenkins-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "jenkins_ecr_policy" {
  name = "${var.cluster_name}-jenkins-kaniko-ecr-policy"
  role = aws_iam_role.jenkins_kaniko_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "helm_release" "jenkins" {
  name             = "jenkins"
  namespace        = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.chart_version
  create_namespace = false
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.module}/values.yaml", {
      github_user           = var.github_user
      github_pat            = var.github_pat
      github_repo_url       = var.github_repo_url
      ecr_registry_endpoint = var.ecr_registry_endpoint
      ecr_repository_name   = var.ecr_repository_name
      ecr_repository_url    = var.ecr_repository_url
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.jenkins,
    kubernetes_service_account_v1.jenkins_sa
  ]
}
