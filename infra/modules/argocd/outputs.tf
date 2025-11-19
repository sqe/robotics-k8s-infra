output "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "https://${var.argocd_domain}"
}

output "argocd_access_command" {
  description = "Command to port-forward ArgoCD UI"
  value       = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443"
}

output "get_initial_password_command" {
  description = "Command to get initial admin password"
  value       = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
