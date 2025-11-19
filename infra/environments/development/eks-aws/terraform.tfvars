# EKS Cluster Configuration
cluster_name = "robotics-eks"
aws_region = "us-east-1"
environment = "development"

# Network
vpc_cidr = "10.0.0.0/16"
allowed_cidr_blocks = ["0.0.0.0/0"]

# Node configuration
control_plane_count = 3
worker_node_count = 3

tags = {
  Project     = "Robotics"
  Platform    = "EKS"
  Environment = "Development"
}
