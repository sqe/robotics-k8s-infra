variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where cluster will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for IP allocation"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for cluster nodes"
  type        = list(string)
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
