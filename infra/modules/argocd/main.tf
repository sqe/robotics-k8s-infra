terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/part-of"    = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  version          = var.argocd_version
  create_namespace = false

  values = [
    templatefile("${path.module}/values.yaml", {
      domain                    = var.argocd_domain
      insecure                  = var.insecure_tls
      dex_enabled              = var.enable_dex
      notifications_enabled    = var.enable_notifications
      server_replicas          = var.server_replicas
      repo_server_replicas     = var.repo_server_replicas
      controller_replicas      = var.controller_replicas
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# Create initial admin secret if specified
resource "kubernetes_secret_v1" "argocd_initial_admin" {
  count = var.initial_admin_password != "" ? 1 : 0

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "password" = var.initial_admin_password
  }

  type = "Opaque"

  depends_on = [helm_release.argocd]
}
