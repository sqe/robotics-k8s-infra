cluster_name        = "robotics-dev"
node_image          = "kindest/node:v1.29.2"
control_plane_count = 3
worker_node_count   = 6
enable_hubble       = false
enable_argocd       = true
github_repo_url     = "https://github.com/sqe/robotics-k8s-infra"
# github_token read from GITHUB_TOKEN environment variable
create_example_app  = true
