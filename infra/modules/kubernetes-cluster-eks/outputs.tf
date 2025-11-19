output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eip.control_plane[0].public_ip
}

output "control_plane_ips" {
  description = "Control plane node public IPs"
  value       = aws_eip.control_plane[*].public_ip
}

output "worker_node_ips" {
  description = "Worker node private IPs"
  value       = aws_network_interface.worker_nodes[*].private_ip
}

output "control_plane_sg_id" {
  description = "Control plane security group ID"
  value       = aws_security_group.control_plane.id
}

output "worker_nodes_sg_id" {
  description = "Worker nodes security group ID"
  value       = aws_security_group.worker_nodes.id
}
