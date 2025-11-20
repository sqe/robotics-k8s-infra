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
  timeout          = 600
  wait             = false

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

# Create GitHub credentials secret if repo URL and token provided
resource "kubernetes_secret_v1" "github_repo" {
  count = var.github_repo_url != "" && var.github_token != "" ? 1 : 0

  metadata {
    name      = "github-repo"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    "type"     = "git"
    "url"      = var.github_repo_url
    "password" = var.github_token
    "username" = "git"
  }

  depends_on = [helm_release.argocd]
}

# Create example ArgoCD Application if requested
resource "kubernetes_manifest" "example_app" {
  count = var.create_example_app && var.github_repo_url != "" ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "robotics-apps"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.github_repo_url
        targetRevision = "HEAD"
        path           = "apps"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret_v1.github_repo]
}
