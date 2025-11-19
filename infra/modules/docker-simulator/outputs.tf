output "container_id" {
  description = "The ID of the Docker container"
  value       = docker_container.ros2_simulator.id
}

output "container_name" {
  description = "The name of the Docker container"
  value       = docker_container.ros2_simulator.name
}

output "network_id" {
  description = "The ID of the Docker network"
  value       = docker_network.ros_net.id
}

output "network_name" {
  description = "The name of the Docker network"
  value       = docker_network.ros_net.name
}

output "image_id" {
  description = "The ID of the ROS 2 Docker image"
  value       = docker_image.ros2_sim_base.image_id
}

output "image_name" {
  description = "The full name of the ROS 2 Docker image"
  value       = docker_image.ros2_sim_base.name
}

output "container_port_mappings" {
  description = "Port mappings for the container"
  value       = docker_container.ros2_simulator.ports
}
