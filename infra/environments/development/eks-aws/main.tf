terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "../../../modules/vpc"

  vpc_cidr_block                = var.vpc_cidr
  public_subnet_a_cidr_block   = var.public_subnet_cidrs
  private_subnet_a_cidr_block  = var.private_subnet_cidrs
  availability_zones           = var.availability_zones
  environment                  = var.environment
}

module "eks_cluster" {
  source = "../../../modules/kubernetes-cluster-eks"

  cluster_name          = var.cluster_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_ids            = module.vpc.subnet_ids
  control_plane_count   = var.control_plane_count
  worker_node_count     = var.worker_node_count
  allowed_cidr_blocks   = var.allowed_cidr_blocks

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

output "cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}

output "control_plane_ips" {
  value = module.eks_cluster.control_plane_ips
}

output "worker_node_ips" {
  value = module.eks_cluster.worker_node_ips
}
