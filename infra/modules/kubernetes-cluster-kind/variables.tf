variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "robotics-cluster"
}

variable "node_image" {
  description = "Docker image to use for cluster nodes"
  type        = string
  default     = "kindest/node:v1.29.2"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.control_plane_count >= 1
    error_message = "Must have at least 1 control plane node."
  }
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 6
  validation {
    condition     = var.worker_node_count >= 0
    error_message = "Worker node count cannot be negative."
  }
}

variable "api_server_port" {
  description = "Port to expose the Kubernetes API server on the host"
  type        = number
  default     = 6444
  validation {
    condition     = var.api_server_port >= 1024 && var.api_server_port <= 65535
    error_message = "API server port must be between 1024 and 65535."
  }
}

variable "calico_version" {
  description = "Version of Calico CNI to install"
  type        = string
  default     = "v3.26.3"
}

variable "metrics_server_version" {
  description = "Version of metrics-server to install"
  type        = string
  default     = "3.11.0"
}

variable "enable_hubble" {
  description = "Enable Cilium Hubble observability"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "local"
    Platform    = "kind"
  }
}
