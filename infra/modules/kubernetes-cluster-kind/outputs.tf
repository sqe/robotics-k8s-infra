output "cluster_name" {
  description = "Name of the kind cluster"
  value       = var.cluster_name
}

output "kubeconfig" {
  description = "Kubeconfig for the cluster"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = data.local_file.kubeconfig.filename
}

output "total_nodes" {
  description = "Total number of nodes in the cluster"
  value       = var.control_plane_count + var.worker_node_count
}

output "control_plane_nodes" {
  description = "Number of control plane nodes"
  value       = var.control_plane_count
}

output "worker_nodes" {
  description = "Number of worker nodes"
  value       = var.worker_node_count
}
