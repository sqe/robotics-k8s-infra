terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Create kind cluster using local script
resource "null_resource" "kind_cluster" {
  provisioner "local-exec" {
    command = "bash ${path.module}/create-cluster.sh ${var.cluster_name} ${var.control_plane_count} ${var.worker_node_count} ${var.node_image} ${var.api_server_port}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.triggers.cluster_name} || true"
  }

  triggers = {
    cluster_name        = var.cluster_name
    control_plane_count = var.control_plane_count
    worker_node_count   = var.worker_node_count
    node_image          = var.node_image
  }
}

# Get kubeconfig
resource "null_resource" "kubeconfig" {
  depends_on = [null_resource.kind_cluster]

  provisioner "local-exec" {
    command = "kind get kubeconfig --name ${var.cluster_name} > /tmp/kubeconfig-${var.cluster_name}"
  }
}

# Read kubeconfig
data "local_file" "kubeconfig" {
  filename = "/tmp/kubeconfig-${var.cluster_name}"

  depends_on = [null_resource.kubeconfig]
}

# Install Cilium and Hubble if enabled
resource "null_resource" "cilium_hubble" {
  count = var.enable_hubble ? 1 : 0

  depends_on = [null_resource.kubeconfig]

  provisioner "local-exec" {
    command = "bash ${path.module}/install-cilium-hubble.sh ${var.cluster_name}"
  }

  triggers = {
    cluster_name = var.cluster_name
    enable_hubble = var.enable_hubble
  }
}
