# Kubernetes Cluster Setup

This project supports two deployment targets:

1. **Kind (Local)** - Kubernetes-in-Docker for local development with multi-node support
2. **EKS (AWS)** - Production-grade AWS Elastic Kubernetes Service

## Directory Structure

```
infra/
├── modules/
│   ├── kubernetes-cluster-kind/     # Kind module with Calico CNI, metrics-server
│   ├── kubernetes-cluster-eks/      # EKS networking infrastructure
│   ├── vpc/                         # VPC for EKS
│   └── ...
└── environments/
    └── development/
        ├── kind-local/              # Local kind cluster (3 control + 6 workers)
        └── eks-aws/                 # AWS EKS deployment
```

## Quick Start - Local Kind Cluster

### Prerequisites

```bash
# Install kind
brew install kind

# Install terraform
brew install terraform

# Install Docker Desktop (or any Docker daemon)
```

### Deploy

```bash
cd infra/environments/development/kind-local
terraform init
terraform plan
terraform apply
```

### Access the Cluster

```bash
# Export kubeconfig
export KUBECONFIG="terraform output -raw kubeconfig_path"

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

### Configuration

Edit `terraform.tfvars`:

```hcl
cluster_name = "robotics-dev"
control_plane_count = 3      # Usually 1 for dev, 3 for high-availability
worker_node_count = 6        # Adjust based on local resources
node_image = "kindest/node:v1.29.2"  # Kubernetes version
```

**Resource Requirements:**
- Each node needs ~1GB RAM + 1 CPU
- With 3 control + 6 workers: ~9GB RAM, 9 CPUs minimum
- Adjust counts based on your machine

### Built-in Components

- **Cilium CNI** - eBPF-based networking with advanced observability
- **Hubble Observability** - Network flow visualization and monitoring
- **Prometheus** - Metrics collection for monitoring
- **Local Storage Class** - For persistent volumes

### Accessing Hubble UI

Once the cluster is running, access the Hubble UI:

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
cilium hubble ui
```

This opens an interactive service map showing:
- Pod-to-pod communication flows
- Network policies in effect
- L7 (application layer) insights
- Performance metrics (latency, throughput)

### Real-time Network Flows

View live network activity:

```bash
cilium hubble observe --follow
```

Filter by namespace:
```bash
cilium hubble observe -n default --follow
```

Filter by pod:
```bash
cilium hubble observe --pod default/my-pod --follow
```

### Cilium Status

Check Cilium health and status:

```bash
cilium status
```

Enable/disable features:
```bash
cilium config set --revert monitoring/metrics=prometheus
cilium config set policyEnforcement=always
```

### ROS 2 / DDS Multicast Support

Cilium supports multicast, which is critical for ROS 2 DDS discovery. The default ROS 2 multicast group is `239.255.0.1:7400`.

Check multicast configuration:
```bash
cilium multicast list
```

Add a multicast group (if needed):
```bash
cilium multicast group join -g 239.255.0.1 -n default
```

For ROS 2 workloads, Cilium automatically handles multicast forwarding across nodes. Verify with:
```bash
# Check multicast endpoints
cilium hubble observe --verdict=INGRESS --type=Trace | grep -i multicast
```

---

## Production - AWS EKS

### Prerequisites

```bash
# AWS credentials configured
aws configure

# Terraform installed
terraform --version
```

### Deploy

```bash
cd infra/environments/development/eks-aws
terraform init
terraform plan
terraform apply
```

### Configuration

Edit `terraform.tfvars`:

```hcl
cluster_name = "robotics-eks"
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
control_plane_count = 3
worker_node_count = 3
allowed_cidr_blocks = ["YOUR_IP/32"]  # Restrict access
```

### Security Groups

- Control plane accepts API requests on port 6443
- Worker nodes accept kubelet requests from control plane
- Node-to-node communication on all ports (TCP/UDP)

### Accessing the Cluster

```bash
# Configure kubectl
aws eks update-kubeconfig --name robotics-eks --region us-east-1

kubectl get nodes
```

---

## Cleanup

### Kind Cluster

```bash
cd infra/environments/development/kind-local
terraform destroy
```

### EKS Cluster

```bash
cd infra/environments/development/eks-aws
terraform destroy
```

---

## Adding ROS2 Deployment

Both cluster types support the robotics stack:

```bash
cd infra
terraform apply -target=module.ros2_deployment
```

See `ROBOTICS_DEPLOYMENT.md` for application setup.

---

## Switching Between Clusters

### Use Kind
```bash
export KUBECONFIG=$(cd infra/environments/development/kind-local && terraform output -raw kubeconfig)
kubectl config current-context
```

### Use EKS
```bash
aws eks update-kubeconfig --name robotics-eks --region us-east-1
kubectl config current-context
```

### List all contexts
```bash
kubectl config get-contexts
```

---

## Monitoring & Debugging

### Check cluster health (any cluster type)
```bash
kubectl get nodes
kubectl get pods -A
kubectl describe node <node-name>
```

### View logs
```bash
kubectl logs -n kube-system -l k8s-app=kubelet --all-containers=true
```

### Monitor resources
```bash
kubectl top nodes
kubectl top pods -A
```

### Local kind cluster - Docker perspective
```bash
docker ps  # See kind containers
docker logs <container-id>  # View node logs
```
