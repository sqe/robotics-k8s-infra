variable "namespace" {
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
  description = "Domain for ArgoCD server"
  type        = string
  default     = "localhost:8080"
}

variable "insecure_tls" {
  description = "Disable TLS verification (for development)"
  type        = bool
  default     = true
}

variable "initial_admin_password" {
  description = "Initial admin password (leave empty to skip)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_dex" {
  description = "Enable Dex for OIDC"
  type        = bool
  default     = false
}

variable "enable_notifications" {
  description = "Enable ArgoCD notifications"
  type        = bool
  default     = false
}

variable "server_replicas" {
  description = "Number of ArgoCD server replicas"
  type        = number
  default     = 1
}

variable "repo_server_replicas" {
  description = "Number of ArgoCD repo server replicas"
  type        = number
  default     = 1
}

variable "controller_replicas" {
  description = "Number of ArgoCD controller replicas"
  type        = number
  default     = 1
}
