variable "namespace" {
  description = "Kubernetes namespace for ROS 2"
  type        = string
  default     = "ros2-workloads"
}

variable "deployment_name" {
  description = "Name of ROS 2 deployment"
  type        = string
  default     = "ros2-node"
}

variable "service_name" {
  description = "Name of ROS 2 service"
  type        = string
  default     = "ros2-service"
}

variable "ros2_image" {
  description = "ROS 2 Docker image"
  type        = string
  default     = "osrf/ros:humble-desktop"
}

variable "image_pull_policy" {
  description = "Image pull policy"
  type        = string
  default     = "IfNotPresent"
}

variable "replicas" {
  description = "Number of ROS 2 pod replicas"
  type        = number
  default     = 1
}

variable "cpu_request" {
  description = "CPU request per pod"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory request per pod"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit per pod"
  type        = string
  default     = "1000m"
}

variable "memory_limit" {
  description = "Memory limit per pod"
  type        = string
  default     = "1Gi"
}

variable "ros_domain_id" {
  description = "ROS 2 domain ID"
  type        = string
  default     = "0"
}

variable "ros_localhost_only" {
  description = "ROS 2 localhost only mode"
  type        = bool
  default     = false
}

variable "node_command" {
  description = "ROS 2 node command to execute"
  type        = string
  default     = "sleep infinity"
}

variable "ros2_setup_script" {
  description = "Base64-encoded ROS 2 setup script"
  type        = string
  default     = "IyEvYmluL2Jhc2gKc291cmNlIC9vcHQvcm9zL2h1bWJsZS9zZXR1cC5iYXNo"
}

variable "ros2_params" {
  description = "Base64-encoded ROS 2 parameters"
  type        = string
  default     = ""
}

variable "service_type" {
  description = "Kubernetes service type"
  type        = string
  default     = "ClusterIP"
}

variable "enable_autoscaling" {
  description = "Enable HPA for ROS 2 workloads"
  type        = bool
  default     = false
}

variable "min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 5
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization percentage"
  type        = number
  default     = 70
}

variable "target_memory_utilization" {
  description = "Target memory utilization percentage"
  type        = number
  default     = 80
}

variable "volume_size_limit" {
  description = "Volume size limit for ROS 2 data"
  type        = string
  default     = "1Gi"
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
