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

# Namespace for ROS 2 workloads
resource "kubernetes_namespace" "ros2" {
  metadata {
    name = var.namespace

    labels = {
      "workload-type" = "robotics"
      "framework"     = "ros2"
    }
  }
}

# ServiceAccount for ROS 2 workloads
resource "kubernetes_service_account" "ros2" {
  metadata {
    name      = "ros2-workload"
    namespace = kubernetes_namespace.ros2.metadata[0].name
  }
}

# ConfigMap for ROS 2 environment setup
resource "kubernetes_config_map" "ros2_config" {
  metadata {
    name      = "ros2-env-config"
    namespace = kubernetes_namespace.ros2.metadata[0].name
  }

  data = {
    "setup.bash" = base64decode(var.ros2_setup_script)
    "params.yaml" = base64decode(var.ros2_params)
  }
}

# NetworkPolicy for ROS 2 pods
resource "kubernetes_network_policy" "ros2" {
  metadata {
    name      = "ros2-network-policy"
    namespace = kubernetes_namespace.ros2.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "ros2-workload"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            "app" = "ros2-workload"
          }
        }
      }

      # Allow DDS communication
      ports {
        port     = "7400"
        protocol = "UDP"
      }
      ports {
        port     = "7401"
        protocol = "UDP"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            "app" = "ros2-workload"
          }
        }
      }

      # Allow DDS communication
      ports {
        port     = "7400"
        protocol = "UDP"
      }
      ports {
        port     = "7401"
        protocol = "UDP"
      }
    }

    # Allow DNS
    egress {
      to {
        namespace_selector {}
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    # Allow external traffic
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
          except = [
            "169.254.169.254/32"
          ]
        }
      }
    }
  }
}

# ROS 2 Node Deployment
resource "kubernetes_deployment" "ros2_node" {
  metadata {
    name      = var.deployment_name
    namespace = kubernetes_namespace.ros2.metadata[0].name

    labels = {
      app = "ros2-workload"
      framework = "ros2"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "ros2-workload"
      }
    }

    template {
      metadata {
        labels = {
          app = "ros2-workload"
          framework = "ros2"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.ros2.metadata[0].name

        init_container {
          name  = "ros2-setup"
          image = var.ros2_image

          command = ["/bin/bash", "-c"]
          args = [
            "source /opt/ros/humble/setup.bash && echo 'ROS 2 environment ready'"
          ]

          volume_mount {
            name       = "ros2-config"
            mount_path = "/root/.ros2"
          }
        }

        container {
          name  = "ros2-node"
          image = var.ros2_image

          image_pull_policy = var.image_pull_policy

          # ROS 2 environment variables
          env {
            name  = "ROS_DOMAIN_ID"
            value = var.ros_domain_id
          }

          env {
            name  = "ROS_LOCALHOST_ONLY"
            value = var.ros_localhost_only ? "1" : "0"
          }

          env {
            name  = "AMENT_PREFIX_PATH"
            value = "/opt/ros/humble"
          }

          env {
            name  = "COLCON_PREFIX_PATH"
            value = "/opt/ros/humble"
          }

          # Container command for running ROS 2 node
          command = ["/bin/bash"]
          args = [
            "-c",
            "source /opt/ros/humble/setup.bash && ${var.node_command}"
          ]

          port {
            name           = "dds-multicast"
            container_port = 7400
            protocol       = "UDP"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_non_root            = false

            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["ALL"]
            }
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          volume_mount {
            name       = "ros2-config"
            mount_path = "/root/.ros2"
          }

          volume_mount {
            name       = "ros2-data"
            mount_path = "/root/ros2_data"
          }

          liveness_probe {
            exec {
              command = ["/bin/bash", "-c", "ps aux | grep -v grep | grep ros"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["/bin/bash", "-c", "ros2 node list 2>/dev/null | grep -q ."]
            }
            initial_delay_seconds = 20
            period_seconds        = 5
          }
        }

        volume {
          name = "ros2-config"
          config_map {
            name = kubernetes_config_map.ros2_config.metadata[0].name
          }
        }

        volume {
          name = "ros2-data"
          empty_dir {
            size_limit = var.volume_size_limit
          }
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["ros2-workload"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        restart_policy = "Always"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }
  }

  depends_on = [kubernetes_namespace.ros2]
}

# Service for ROS 2 node discovery
resource "kubernetes_service" "ros2_node" {
  metadata {
    name      = var.service_name
    namespace = kubernetes_namespace.ros2.metadata[0].name

    labels = {
      app = "ros2-workload"
    }
  }

  spec {
    selector = {
      app = "ros2-workload"
    }

    type = var.service_type

    port {
      name       = "dds-multicast"
      port       = 7400
      protocol   = "UDP"
      target_port = "dds-multicast"
    }

    port {
      name       = "dds-unicast"
      port       = 7401
      protocol   = "UDP"
      target_port = 7401
    }
  }
}

# HorizontalPodAutoscaler for ROS 2 workloads
resource "kubernetes_horizontal_pod_autoscaler_v2" "ros2" {
  count = var.enable_autoscaling ? 1 : 0

  metadata {
    name      = "${var.deployment_name}-hpa"
    namespace = kubernetes_namespace.ros2.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.ros2_node.metadata[0].name
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    metric {
      type = "Resource"

      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.target_cpu_utilization
        }
      }
    }

    metric {
      type = "Resource"

      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = var.target_memory_utilization
        }
      }
    }
  }
}

# Outputs
output "ros2_namespace" {
  description = "ROS 2 namespace"
  value       = kubernetes_namespace.ros2.metadata[0].name
}

output "ros2_deployment_name" {
  description = "ROS 2 deployment name"
  value       = kubernetes_deployment.ros2_node.metadata[0].name
}

output "ros2_service_name" {
  description = "ROS 2 service name"
  value       = kubernetes_service.ros2_node.metadata[0].name
}

output "ros2_service_cluster_ip" {
  description = "ROS 2 service cluster IP"
  value       = kubernetes_service.ros2_node.spec[0].cluster_ip
}
