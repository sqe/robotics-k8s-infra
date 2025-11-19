variable "ros2_image" {
  description = "Docker image for ROS 2 simulator"
  type        = string
  default     = "arm64v8/ros:humble"
}

variable "container_name" {
  description = "Name of the Docker container"
  type        = string
  default     = "ros2-tf-simulator"
}

variable "network_name" {
  description = "Name of the Docker network"
  type        = string
  default     = "ros2_tf_network"
}

variable "network_driver" {
  description = "Docker network driver"
  type        = string
  default     = "bridge"
}

variable "keep_image_locally" {
  description = "Keep the image locally after pulling"
  type        = bool
  default     = true
}

variable "restart_policy" {
  description = "Restart policy for the container"
  type        = string
  default     = "unless-stopped"
  
  validation {
    condition     = contains(["no", "always", "unless-stopped", "on-failure"], var.restart_policy)
    error_message = "restart_policy must be one of: no, always, unless-stopped, on-failure"
  }
}

variable "port_mappings" {
  description = "Port mappings for the container"
  type = list(object({
    internal = number
    external = number
  }))
  default = [
    {
      internal = 5900
      external = 5901
    }
  ]
}

variable "volume_mounts" {
  description = "Volume mounts for the container"
  type = list(object({
    host_path      = string
    container_path = string
  }))
  default = []
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = list(string)
  default     = []
}

variable "cpu_shares" {
  description = "CPU shares for the container"
  type        = number
  default     = 1024
}

variable "memory_mb" {
  description = "Memory limit for the container in MB"
  type        = number
  default     = 2048
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    "environment" = "development"
    "application" = "ros2-simulator"
  }
}
