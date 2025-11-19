variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "robotics-dev"
}

variable "node_image" {
  description = "Kind node image version"
  type        = string
  default     = "kindest/node:v1.29.2"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 6
}

variable "enable_hubble" {
  description = "Enable Cilium Hubble observability"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps workload management"
  type        = bool
  default     = true
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.0.0"
}

variable "argocd_domain" {
  description = "ArgoCD domain"
  type        = string
  default     = "localhost:8080"
}
