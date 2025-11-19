terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Pull base ROS 2 image for simulation
resource "docker_image" "ros2_sim_base" {
  name         = var.ros2_image
  keep_locally = var.keep_image_locally
  platform     = "linux/arm64"

  pull_triggers = [var.ros2_image]
}

# Create a local network for the container
resource "docker_network" "ros_net" {
  name   = var.network_name
  driver = var.network_driver

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# Launch the ROS 2 simulator container
resource "docker_container" "ros2_simulator" {
  name    = var.container_name
  image   = docker_image.ros2_sim_base.image_id
  command = ["/bin/bash", "-c", "while true; do sleep 10; done"]
  stdin_open = true
  tty = true  

  # Map ports for external VNC access or RVIZ visualization
  dynamic "ports" {
    for_each = var.port_mappings
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  # Connect to the created network
  networks_advanced {
    name = docker_network.ros_net.name
  }

  # Mount volumes for configuration files
  dynamic "volumes" {
    for_each = var.volume_mounts
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }

  # Environment variables for the container
  env = var.environment_variables

  # Resource limits
  cpu_shares = var.cpu_shares
  memory     = var.memory_mb

  # Container labels
  dynamic "labels" {
    for_each = merge(
      var.labels,
      {
        "managed-by" = "terraform"
        "component"  = "ros2-simulator"
      }
    )
    content {
      label = labels.key
      value = labels.value
    }
  }
}
