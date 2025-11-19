terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Robotics Automation"
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for i, az in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Route53 Zone for cluster
resource "aws_route53_zone" "cluster" {
  name = var.cluster_domain

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = {
    Name = "${var.cluster_name}-zone"
  }
}

# Kubernetes Cluster Infrastructure
module "kubernetes_cluster" {
  source = "../../../modules/kubernetes-cluster"

  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  subnet_ids         = module.vpc.private_subnets
  control_plane_count = var.control_plane_count
  worker_node_count  = var.worker_node_count
  route53_zone_id    = aws_route53_zone.cluster.zone_id
  domain_name        = var.cluster_domain

  tags = {
    ClusterName = var.cluster_name
  }
}

# RDS Aurora for application data
module "aurora_postgresql" {
  source = "../../../modules/rds-aurora-pg"

  environment             = var.environment
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  region                 = var.aws_region
  backup_retention_period = var.backup_retention_period
  rds_security_group_id  = aws_security_group.rds.id

  tags = {
    ClusterName = var.cluster_name
  }
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.kubernetes_cluster.worker_nodes_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

# Kubernetes Provider configuration
provider "kubernetes" {
  host                   = "https://${module.kubernetes_cluster.cluster_endpoint}:6443"
  insecure              = false
  skip_credentials_validation = true
  skip_requesting_account_id = true
}

provider "helm" {
  kubernetes {
    host = "https://${module.kubernetes_cluster.cluster_endpoint}:6443"
    insecure = false
    skip_credentials_validation = true
    skip_requesting_account_id = true
  }
}

# Generate kubeconfig
resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig"
  content = base64decode(aws_s3_object.kubeconfig[0].body)
  
  depends_on = [module.kubernetes_cluster]
}

# Store kubeconfig in S3
resource "aws_s3_bucket" "kubeconfig_bucket" {
  bucket_prefix = "${var.cluster_name}-config-"

  tags = {
    Name = "${var.cluster_name}-config"
  }
}

resource "aws_s3_object" "kubeconfig" {
  count  = 1
  bucket = aws_s3_bucket.kubeconfig_bucket.id
  key    = "kubeconfig"
  content = base64encode(templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name     = var.cluster_name
    cluster_endpoint = module.kubernetes_cluster.cluster_endpoint
  }))

  tags = {
    Name = "kubeconfig"
  }
}

# Ansible Inventory generation
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../ansible/inventory-dynamic.yml"
  content = templatefile("${path.module}/inventory.tpl", {
    control_plane_ips      = module.kubernetes_cluster.control_plane_ips
    control_plane_hostnames = module.kubernetes_cluster.control_plane_hostnames
    worker_ips             = module.kubernetes_cluster.worker_node_ips
    worker_hostnames       = module.kubernetes_cluster.worker_node_hostnames
  })

  depends_on = [module.kubernetes_cluster]
}

# KubeEdge Gateway deployment
module "kubeedge_gateway" {
  source = "../../../modules/kubeedge-gateway"

  namespace  = "kubeedge"
  cloudcore_image = var.kubeedge_cloudcore_image
  cloudcore_config = base64encode(var.kubeedge_cloudcore_config)
  cloudcore_replicas = var.kubeedge_replicas

  depends_on = [module.kubernetes_cluster]
}

# ROS 2 Deployment
module "ros2_deployment" {
  source = "../../../modules/ros2-deployment"

  namespace          = "ros2-workloads"
  deployment_name    = "ros2-node"
  ros2_image         = var.ros2_image
  replicas           = var.ros2_replicas
  
  ros_domain_id      = var.ros_domain_id
  ros_localhost_only = var.ros_localhost_only
  
  node_command       = var.ros2_node_command
  
  cpu_request  = var.ros2_cpu_request
  memory_request = var.ros2_memory_request
  cpu_limit    = var.ros2_cpu_limit
  memory_limit = var.ros2_memory_limit

  enable_autoscaling = var.ros2_enable_autoscaling
  min_replicas      = var.ros2_min_replicas
  max_replicas      = var.ros2_max_replicas

  depends_on = [module.kubernetes_cluster]
}

# Outputs
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.kubernetes_cluster.cluster_endpoint
}

output "control_plane_ips" {
  description = "Control plane node public IPs"
  value       = module.kubernetes_cluster.control_plane_ips
}

output "worker_node_ips" {
  description = "Worker node private IPs"
  value       = module.kubernetes_cluster.worker_node_ips
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.aurora_postgresql.cluster_endpoint
}

output "rds_master_username" {
  description = "RDS master username"
  value       = module.aurora_postgresql.master_username
}

output "kubeedge_service_endpoint" {
  description = "KubeEdge service endpoint"
  value       = try(module.kubeedge_gateway.cloudcore_service_endpoint, "")
}

output "ros2_namespace" {
  description = "ROS 2 namespace"
  value       = module.ros2_deployment.ros2_namespace
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "ansible_inventory_path" {
  description = "Path to Ansible inventory"
  value       = local_file.ansible_inventory.filename
}
