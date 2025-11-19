# Docker Simulator Module

This module manages Docker resources for local development environments, specifically designed to launch and manage a ROS 2 simulator container.

## Overview

The Docker provider allows you to manage Docker resources directly on a host where Terraform is executed. This module demonstrates the capability to:

- Pull and manage Docker images
- Create and manage Docker networks
- Launch and configure containers with port mappings and volume mounts
- Define resource constraints and environment variables

## Requirements

- **Docker**: Must be running on the host where Terraform is executed
- **Docker Provider**: kreuzwerker/docker ~> 3.0
- **Docker Socket Access**: 
  - Linux/Mac: `/var/run/docker.sock` (default)
  - Windows: `npipe:////./pipe/docker_engine` (set via `DOCKER_HOST` environment variable)

## Usage

### Basic Example

```hcl
module "docker_simulator" {
  source = "../../../modules/docker-simulator"

  container_name = "dev-ros2-simulator"
  network_name   = "dev-ros2-network"
  ros2_image     = "osrf/ros:humble-desktop"

  port_mappings = [
    {
      internal = 5900
      external = 5900
    }
  ]

  memory_mb = 2048
  cpu_shares = 1024
}
```

### Advanced Example with Volume Mounts

```hcl
module "docker_simulator" {
  source = "../../../modules/docker-simulator"

  container_name = "dev-ros2-simulator"
  network_name   = "dev-ros2-network"

  port_mappings = [
    {
      internal = 5900
      external = 5900
    },
    {
      internal = 8080
      external = 8080
    }
  ]

  volume_mounts = [
    {
      host_path      = "/path/to/sim_config/params.yaml"
      container_path = "/root/sim_config/params.yaml"
    },
    {
      host_path      = "/path/to/sensor/specs"
      container_path = "/root/sensor_specs"
    }
  ]

  environment_variables = [
    "ROS_DOMAIN_ID=0",
    "ROS_LOCALHOST_ONLY=0",
    "ROS_LOG_DIR=/tmp/ros_logs"
  ]

  labels = {
    environment = "development"
    application = "ros2-simulator"
    team        = "robotics"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ros2_image` | Docker image for ROS 2 simulator | string | `"osrf/ros:humble-desktop"` | no |
| `container_name` | Name of the Docker container | string | `"ros2-tf-simulator"` | no |
| `network_name` | Name of the Docker network | string | `"ros2_tf_network"` | no |
| `network_driver` | Docker network driver | string | `"bridge"` | no |
| `keep_image_locally` | Keep the image locally after pulling | bool | `true` | no |
| `restart_policy` | Restart policy for the container | string | `"unless-stopped"` | no |
| `port_mappings` | Port mappings for the container | list(object({internal=number, external=number})) | `[{internal=5900, external=5900}]` | no |
| `volume_mounts` | Volume mounts for the container | list(object({host_path=string, container_path=string})) | `[]` | no |
| `environment_variables` | Environment variables for the container | list(string) | `[]` | no |
| `cpu_shares` | CPU shares for the container | number | `1024` | no |
| `memory_mb` | Memory limit for the container in MB | number | `2048` | no |
| `labels` | Labels to apply to resources | map(string) | See variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| `container_id` | The ID of the Docker container |
| `container_name` | The name of the Docker container |
| `network_id` | The ID of the Docker network |
| `network_name` | The name of the Docker network |
| `image_id` | The ID of the ROS 2 Docker image |
| `image_name` | The full name of the ROS 2 Docker image |
| `container_port_mappings` | Port mappings for the container |

## Competency Demonstrated

This module demonstrates proficiency with:

- **Docker Provider Integration**: Using terraform-docker provider to define and manage container lifecycle
- **Modular Design**: Encapsulating Docker configuration in a reusable module with flexible inputs
- **Resource Constraints**: Defining CPU and memory limits for containers
- **Network Management**: Creating isolated Docker networks for service communication
- **Volume Management**: Mounting host paths into containers for persistent configuration
- **Port Mapping**: Exposing container ports for external access (e.g., VNC visualization)
- **Environment Configuration**: Managing container environment variables for runtime behavior

## Accessing the Simulator

Once deployed, the ROS 2 simulator can be accessed via:

- **VNC Visualization**: `localhost:5900` (if VNC server is running in the container)
- **Container Shell**: `docker exec -it <container-name> /bin/bash`
- **Logs**: `docker logs <container-name>`

## Cleanup

To destroy the Docker resources created by this module:

```bash
terraform destroy -target=module.docker_simulator
```

## Notes

- The Docker daemon must be running on the host where Terraform is executed
- The user running Terraform must have permission to access the Docker socket
- On Linux, this typically requires the user to be in the `docker` group or have sudo access
- Volume mounts require the host paths to exist or be created prior to container startup
- The module automatically adds managed labels to resources for tracking and identification
