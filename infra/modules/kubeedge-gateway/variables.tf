variable "namespace" {
  description = "Kubernetes namespace for KubeEdge"
  type        = string
  default     = "kubeedge"
}

variable "cloudcore_image" {
  description = "KubeEdge CloudCore image"
  type        = string
  default     = "kubeedge/cloudcore:latest"
}

variable "cloudcore_replicas" {
  description = "Number of CloudCore replicas"
  type        = number
  default     = 1
}

variable "cloudcore_config" {
  description = "Base64-encoded CloudCore configuration"
  type        = string
}

variable "cloudcore_cpu_request" {
  description = "CloudCore CPU request"
  type        = string
  default     = "200m"
}

variable "cloudcore_memory_request" {
  description = "CloudCore memory request"
  type        = string
  default     = "256Mi"
}

variable "cloudcore_cpu_limit" {
  description = "CloudCore CPU limit"
  type        = string
  default     = "500m"
}

variable "cloudcore_memory_limit" {
  description = "CloudCore memory limit"
  type        = string
  default     = "512Mi"
}

variable "enable_metrics" {
  description = "Enable KubeEdge metrics"
  type        = bool
  default     = true
}

variable "create_rbac" {
  description = "Create RBAC resources"
  type        = bool
  default     = true
}
