terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security group for control plane
resource "aws_security_group" "control_plane" {
  name_prefix = "${var.cluster_name}-cp-"
  description = "Security group for Kubernetes control plane"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Kubernetes API"
  }

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
    description = "etcd"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cp-sg"
  })
}

# Security group for worker nodes
resource "aws_security_group" "worker_nodes" {
  name_prefix = "${var.cluster_name}-worker-"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane.id]
    description     = "kubelet API"
  }

  ingress {
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    cidr_blocks     = var.allowed_cidr_blocks
    description     = "NodePort services"
  }

  # Allow worker-to-worker communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Worker to worker"
  }

  # Allow CNI communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
    description = "CNI communication"
  }

  # Allow control plane to workers
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane.id]
    description     = "Control plane to workers"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-worker-sg"
  })
}

# Elastic IPs for control plane nodes
resource "aws_eip" "control_plane" {
  count  = var.control_plane_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cp-eip-${count.index + 1}"
  })

  depends_on = [aws_security_group.control_plane]
}

# ENIs for control plane nodes with fixed private IPs
resource "aws_network_interface" "control_plane" {
  count           = var.control_plane_count
  subnet_id       = var.subnet_ids[count.index % length(var.subnet_ids)]
  security_groups = [aws_security_group.control_plane.id]
  
  private_ips = ["${cidrhost(var.vpc_cidr, 10 + count.index)}"]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cp-eni-${count.index + 1}"
  })
}

# Associate EIPs with control plane ENIs
resource "aws_eip_association" "control_plane" {
  count            = var.control_plane_count
  allocation_id    = aws_eip.control_plane[count.index].id
  network_interface_id = aws_network_interface.control_plane[count.index].id
}

# ENIs for worker nodes
resource "aws_network_interface" "worker_nodes" {
  count           = var.worker_node_count
  subnet_id       = var.subnet_ids[count.index % length(var.subnet_ids)]
  security_groups = [aws_security_group.worker_nodes.id]
  
  private_ips = ["${cidrhost(var.vpc_cidr, 50 + count.index)}"]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-worker-eni-${count.index + 1}"
  })
}

# Output cluster endpoint for kubeconfig
output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eip.control_plane[0].public_ip
}

output "control_plane_ips" {
  description = "Control plane node IPs"
  value       = aws_eip.control_plane[*].public_ip
}

output "worker_node_ips" {
  description = "Worker node private IPs"
  value       = aws_network_interface.worker_nodes[*].private_ip
}

output "control_plane_sg_id" {
  description = "Control plane security group"
  value       = aws_security_group.control_plane.id
}

output "worker_sg_id" {
  description = "Worker nodes security group"
  value       = aws_security_group.worker_nodes.id
}
