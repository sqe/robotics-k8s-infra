terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

# KubeEdge CloudCore deployment
resource "kubernetes_namespace" "kubeedge" {
  metadata {
    name = var.namespace
  }
}

# ServiceAccount for KubeEdge CloudCore
resource "kubernetes_service_account" "kubeedge_cloudcore" {
  metadata {
    name      = "cloudcore"
    namespace = kubernetes_namespace.kubeedge.metadata[0].name
  }
}

# ClusterRole for KubeEdge CloudCore
resource "kubernetes_cluster_role" "kubeedge_cloudcore" {
  metadata {
    name = "cloudcore"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "nodes/proxy", "services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["patch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["devices.kubeedge.io"]
    resources  = ["devices", "devicemodels"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "kubeedge_cloudcore" {
  metadata {
    name = "cloudcore"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kubeedge_cloudcore.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubeedge_cloudcore.metadata[0].name
    namespace = kubernetes_namespace.kubeedge.metadata[0].name
  }
}

# ConfigMap for KubeEdge CloudCore config
resource "kubernetes_config_map" "kubeedge_cloudcore_config" {
  metadata {
    name      = "cloudcore-config"
    namespace = kubernetes_namespace.kubeedge.metadata[0].name
  }

  data = {
    "cloudcore.yaml" = base64decode(var.cloudcore_config)
  }
}

# Deployment for KubeEdge CloudCore
resource "kubernetes_deployment" "kubeedge_cloudcore" {
  metadata {
    name      = "cloudcore"
    namespace = kubernetes_namespace.kubeedge.metadata[0].name
  }

  spec {
    replicas = var.cloudcore_replicas

    selector {
      match_labels = {
        app = "kubeedge"
        tier = "cloudcore"
      }
    }

    template {
      metadata {
        labels = {
          app = "kubeedge"
          tier = "cloudcore"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.kubeedge_cloudcore.metadata[0].name

        container {
          name  = "cloudcore"
          image = var.cloudcore_image

          port {
            name           = "websocket"
            container_port = 10000
          }

          port {
            name           = "quic"
            container_port = 10001
          }

          port {
            name           = "https"
            container_port = 10002
          }

          env {
            name  = "KUBEEDGE_CLOUDCORE_ENABLE_METRICS"
            value = var.enable_metrics ? "true" : "false"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/kubeedge"
          }

          resources {
            requests = {
              cpu    = var.cloudcore_cpu_request
              memory = var.cloudcore_memory_request
            }
            limits = {
              cpu    = var.cloudcore_cpu_limit
              memory = var.cloudcore_memory_limit
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.kubeedge_cloudcore_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.kubeedge]
}

# Service for KubeEdge CloudCore
resource "kubernetes_service" "kubeedge_cloudcore" {
  metadata {
    name      = "cloudcore"
    namespace = kubernetes_namespace.kubeedge.metadata[0].name
  }

  spec {
    selector = {
      app = "kubeedge"
      tier = "cloudcore"
    }

    type = "LoadBalancer"

    port {
      name       = "websocket"
      port       = 10000
      protocol   = "TCP"
      target_port = 10000
    }

    port {
      name       = "quic"
      port       = 10001
      protocol   = "UDP"
      target_port = 10001
    }

    port {
      name       = "https"
      port       = 10002
      protocol   = "TCP"
      target_port = 10002
    }
  }
}

# RBAC for edge node management
resource "kubernetes_cluster_role" "edge_management" {
  metadata {
    name = "kubeedge-edge-management"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/status"]
    verbs      = ["patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

# Output endpoints
output "cloudcore_service_endpoint" {
  description = "KubeEdge CloudCore service endpoint"
  value       = kubernetes_service.kubeedge_cloudcore.status[0].load_balancer[0].ingress[0].hostname
}

output "cloudcore_service_ip" {
  description = "KubeEdge CloudCore service IP"
  value       = kubernetes_service.kubeedge_cloudcore.spec[0].cluster_ip
}

output "kubeedge_namespace" {
  description = "KubeEdge namespace"
  value       = kubernetes_namespace.kubeedge.metadata[0].name
}
