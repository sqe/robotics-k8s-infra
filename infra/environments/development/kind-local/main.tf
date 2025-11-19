terraform {
  required_version = ">= 1.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

module "kind_cluster" {
  source = "../../../modules/kubernetes-cluster-kind"

  cluster_name        = var.cluster_name
  node_image          = var.node_image
  control_plane_count = var.control_plane_count
  worker_node_count   = var.worker_node_count
  enable_hubble       = var.enable_hubble
}

# Configure kubernetes and helm providers to use the kind cluster
provider "kubernetes" {
  config_path = module.kind_cluster.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = module.kind_cluster.kubeconfig_path
  }
}

# Deploy ArgoCD for workload management
module "argocd" {
  source = "../../../modules/argocd"

  count = var.enable_argocd ? 1 : 0

  namespace                = var.argocd_namespace
  argocd_version          = var.argocd_version
  argocd_domain           = var.argocd_domain
  insecure_tls            = true  # For development
  server_replicas         = 1
  repo_server_replicas    = 1
  controller_replicas     = 1

  depends_on = [module.kind_cluster]
}

output "cluster_name" {
  value = module.kind_cluster.cluster_name
}

output "kubeconfig_path" {
  value = module.kind_cluster.kubeconfig_path
}

output "total_nodes" {
  value = module.kind_cluster.total_nodes
}

output "kubeconfig" {
  value     = module.kind_cluster.kubeconfig
  sensitive = true
}

output "argocd_namespace" {
  value = try(module.argocd[0].argocd_namespace, "Not deployed")
}

output "argocd_access_command" {
  value = try(module.argocd[0].argocd_access_command, "Not deployed")
}

output "argocd_initial_password_command" {
  value = try(module.argocd[0].get_initial_password_command, "Not deployed")
}
