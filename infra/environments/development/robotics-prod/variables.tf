variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "robotics-cluster"
}

variable "cluster_domain" {
  description = "Cluster domain name"
  type        = string
  default     = "robotics.local"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
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

variable "backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

# KubeEdge variables
variable "kubeedge_cloudcore_image" {
  description = "KubeEdge CloudCore image"
  type        = string
  default     = "kubeedge/cloudcore:1.14.0"
}

variable "kubeedge_cloudcore_config" {
  description = "KubeEdge CloudCore configuration"
  type        = string
  default     = <<-EOT
    modules:
      cloudHub:
        nodeLimit: 1000
        quicMaxStreamReceiveWindow: 1000000
        maxIncomingStreams: 10000
      edgeController:
        nodeUpdateFrequency: 10
  EOT
}

variable "kubeedge_replicas" {
  description = "Number of KubeEdge CloudCore replicas"
  type        = number
  default     = 1
}

# ROS 2 variables
variable "ros2_image" {
  description = "ROS 2 Docker image"
  type        = string
  default     = "osrf/ros:humble-desktop"
}

variable "ros2_replicas" {
  description = "Number of ROS 2 pod replicas"
  type        = number
  default     = 1
}

variable "ros_domain_id" {
  description = "ROS domain ID"
  type        = string
  default     = "0"
}

variable "ros_localhost_only" {
  description = "ROS localhost only mode"
  type        = bool
  default     = false
}

variable "ros2_node_command" {
  description = "ROS 2 node command"
  type        = string
  default     = "sleep infinity"
}

variable "ros2_cpu_request" {
  description = "ROS 2 CPU request"
  type        = string
  default     = "500m"
}

variable "ros2_memory_request" {
  description = "ROS 2 memory request"
  type        = string
  default     = "512Mi"
}

variable "ros2_cpu_limit" {
  description = "ROS 2 CPU limit"
  type        = string
  default     = "1000m"
}

variable "ros2_memory_limit" {
  description = "ROS 2 memory limit"
  type        = string
  default     = "1Gi"
}

variable "ros2_enable_autoscaling" {
  description = "Enable ROS 2 autoscaling"
  type        = bool
  default     = false
}

variable "ros2_min_replicas" {
  description = "Minimum ROS 2 replicas"
  type        = number
  default     = 1
}

variable "ros2_max_replicas" {
  description = "Maximum ROS 2 replicas"
  type        = number
  default     = 5
}
