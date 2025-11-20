# Ansible-based KinD + KubeEdge + ROS2 Deployment

Alternative to Terraform for provisioning the complete robotics platform locally using Ansible playbooks.

## Feature Parity

This Ansible setup provides full feature parity with the Terraform+Bash setup:

| Component | Terraform | Ansible |
|-----------|-----------|---------|
| KinD Cluster Creation | ✅ | ✅ |
| Multi control plane | ✅ | ✅ |
| Multi worker nodes | ✅ | ✅ |
| Cilium CNI | ✅ | ✅ |
| Cilium Hubble (observability) | ✅ | ✅ |
| Metrics Server | ✅ | ✅ |
| KubeEdge CloudCore | ✅ | ✅ |
| WebSocket/QUIC/HTTPS tunnels | ✅ | ✅ |
| Edge node join script | ✅ | ✅ |
| ArgoCD GitOps | ✅ | ✅ |
| ROS2 Applications | ✅ | ✅ |
| Multi-domain DDS support | ✅ | ✅ |

## Prerequisites

```bash
# Required tools
ansible --version          # >= 2.9
kubectl version --client   # >= 1.28
kind version              # >= 0.20
helm version              # >= 3.0
python3 --version         # >= 3.8
```

Install Ansible:
```bash
pip install ansible
```

Install required Ansible collections:
```bash
ansible-galaxy collection install kubernetes.core
```

## Quick Start

### Single Command Deployment

Deploy everything (KinD + KubeEdge + ArgoCD + ROS2) in one go:

```bash
cd infra/ansible
ansible-playbook playbooks/site.yml
```

### Step-by-Step Deployment

1. **Create KinD cluster:**
   ```bash
   ansible-playbook playbooks/provision-kind-cluster.yml
   ```
   
   Optional: Customize cluster parameters
   ```bash
   ansible-playbook playbooks/provision-kind-cluster.yml \
     -e "cluster_name=my-cluster control_plane_count=3 worker_node_count=6"
   ```

2. **Deploy KubeEdge CloudCore:**
   ```bash
   ansible-playbook playbooks/deploy-kubeedge.yml
   ```

3. **Deploy ArgoCD (GitOps):**
   ```bash
   ansible-playbook playbooks/deploy-argocd.yml
   ```
   
   With GitHub integration:
   ```bash
   ansible-playbook playbooks/deploy-argocd.yml \
     -e "github_repo_url=https://github.com/user/repo github_token=<token>"
   ```

4. **Deploy ROS2 Applications:**
   ```bash
   ansible-playbook playbooks/deploy-ros2.yml
   ```

## Playbooks Overview

### provision-kind-cluster.yml

Creates a local KinD cluster with:
- Configurable control plane and worker nodes
- Cilium CNI deployment
- Hubble observability (optional)
- Metrics Server
- Port mappings for KubeEdge communication

**Variables:**
- `cluster_name`: Name of the cluster (default: robotics-dev)
- `control_plane_count`: Number of control plane nodes (default: 3)
- `worker_node_count`: Number of worker nodes (default: 6)
- `k8s_version`: Kubernetes version (default: v1.29.2)
- `enable_hubble`: Enable Cilium Hubble (default: true)

### deploy-kubeedge.yml

Deploys KubeEdge CloudCore with:
- CloudCore Deployment with proper RBAC
- MQTT EventBus
- WebSocket, QUIC, and HTTPS tunnels
- Metrics endpoint
- LoadBalancer Service
- Edge node join script generation

**Variables:**
- `kubeedge_version`: KubeEdge version (default: 1.15.0)
- `edgemesh_version`: EdgeMesh version (default: 1.12.0)

**Outputs:**
- `/tmp/join-edge-node.sh` - Script to join edge nodes

### deploy-argocd.yml

Deploys ArgoCD for GitOps workflow with:
- ArgoCD server, repo-server, and controller
- Insecure mode for local development
- Optional GitHub repository integration
- Example application CRD (optional)

**Variables:**
- `argocd_version`: ArgoCD Helm chart version (default: 7.0.0)
- `argocd_domain`: Domain for ArgoCD (default: localhost:8080)
- `github_repo_url`: GitHub repo URL (optional)
- `github_token`: GitHub token (optional, via env var)
- `create_example_app`: Create example app (default: false)

**Access:**
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access at https://localhost:8080
# Username: admin
# Password: argocd (or check logs)
```

### deploy-ros2.yml

Deploys ROS2 applications with:
- FastDDS Discovery Server (Domain 42)
- ROS2 Talker + Listener (Domain 42, Cloud)
- IoT Sensor App (Domain 43, Isolated)
- Multi-domain DDS network isolation

**Variables:**
- `ros_version`: ROS2 distribution (default: humble)
- `ros_image`: ROS2 Docker image (default: arm64v8/ros:humble)

### site.yml

Orchestrates complete deployment:
- Runs all playbooks in sequence
- Applies tags for selective execution
- Provides final status report

**Tags:**
```bash
# Run only KinD provisioning
ansible-playbook playbooks/site.yml -t provision-kind

# Run KubeEdge deployment
ansible-playbook playbooks/site.yml -t deploy-kubeedge

# Run complete setup
ansible-playbook playbooks/site.yml -t full-setup
```

## Common Tasks

### View Cluster Status

```bash
# All nodes
kubectl get nodes -o wide

# CloudCore pods
kubectl get pods -n kubeedge

# ROS2 applications
kubectl get pods -l ros-domain=42

# ArgoCD
kubectl get pods -n argocd
```

### Monitor ROS2 Communication

```bash
# View talker output
kubectl logs -f deployment/ros2-talker-cloud

# View listener output
kubectl logs -f deployment/ros2-listener-cloud

# Exec into pod
kubectl exec -it <pod-name> -- bash
```

### Register Real Edge Device

After deploying CloudCore:

```bash
# Get CloudCore IP
kubectl get svc cloudcore -n kubeedge

# On edge device, run the join script
scp /tmp/join-edge-node.sh <device>:/tmp/
ssh <device> '/tmp/join-edge-node.sh robot-edge-01 <cloudcore-ip> 10000'
```

### Access ArgoCD UI

```bash
# Port forward to local machine
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open https://localhost:8080
# Username: admin
# Get password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Deploy ROS2 to Edge Node

Using edge-node-manager CLI (from terraform setup):

```bash
python3 edge-node-manager.py simulate-edge \
  --node-name robot-edge-01 \
  --worker-node robotics-dev-worker \
  --domain-id 42
```

## Inventory

The `inventory.yml` file defines host groups for cloud infrastructure deployments. For local KinD setup, all operations run on localhost.

To use with remote machines (AWS, etc.), update:

```yaml
k8s_control_plane:
  hosts:
    k8s-cp-1:
      ansible_host: <ip>
      
k8s_workers:
  hosts:
    k8s-worker-1:
      ansible_host: <ip>
```

## Environment Variables

Set KUBECONFIG if not using default:

```bash
export KUBECONFIG=/path/to/kubeconfig
ansible-playbook playbooks/site.yml
```

For GitHub integration in ArgoCD:

```bash
export GITHUB_REPO_URL=https://github.com/user/repo
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
ansible-playbook playbooks/deploy-argocd.yml
```

## Idempotency

All playbooks are idempotent - running them multiple times is safe:

```bash
# Safe to run repeatedly
ansible-playbook playbooks/site.yml
```

Existing resources won't be recreated, only updated if changed.

## Troubleshooting

### KinD Cluster Creation Fails

```bash
# Check kind is installed
kind --version

# Check Docker is running
docker ps

# Check if cluster already exists
kind get clusters
```

### CloudCore Won't Start

```bash
# Check logs
kubectl logs -f deployment/cloudcore -n kubeedge

# Check resource requests
kubectl describe pod -n kubeedge

# Check RBAC permissions
kubectl get clusterrole cloudcore
```

### ROS2 Pods Not Ready

```bash
# Check pod status
kubectl describe pod <ros2-pod>

# Check logs
kubectl logs <ros2-pod>

# Verify image pulled successfully
kubectl get events -n default
```

### ArgoCD Not Accessible

```bash
# Check service
kubectl get svc -n argocd

# Check pod status
kubectl get pods -n argocd

# Check logs
kubectl logs deployment/argocd-server -n argocd
```

## Cleanup

### Remove Entire Setup

```bash
# Delete KinD cluster (deletes all resources)
kind delete cluster --name robotics-dev
```

### Remove Specific Components

```bash
# Delete KubeEdge
kubectl delete namespace kubeedge

# Delete ArgoCD
kubectl delete namespace argocd

# Delete ROS2 apps
kubectl delete deployment -l ros-domain=42
```

## Comparison with Terraform

| Aspect | Terraform | Ansible |
|--------|-----------|---------|
| Language | HCL | YAML |
| State Management | terraform.state | None (idempotent) |
| Learning Curve | Moderate | Easier for ops folks |
| Debugging | terraform plan | -vvv flags |
| Modularity | Modules | Playbooks/Roles |
| Cloud Agnostic | Yes | Yes |
| Kubernetes Native | Provider needed | kubernetes.core collection |

**When to use Ansible:**
- Team familiar with Ansible
- No state management needed
- Prefer YAML over HCL
- Want simple, readable automation

**When to use Terraform:**
- Multi-cloud deployments
- Need infrastructure state
- Deploying to AWS/GCP/Azure
- Want IaC best practices

## Next Steps

1. **Production Hardening:**
   - Use real TLS certificates (not self-signed)
   - Set ArgoCD admin password
   - Configure RBAC for edge nodes
   - Enable network policies

2. **Scaling:**
   - Add more control planes
   - Deploy to multiple worker nodes
   - Register real edge devices
   - Monitor with Prometheus/Grafana

3. **Integration:**
   - Connect GitHub for ArgoCD
   - Add custom ROS2 applications
   - Deploy real robotics workloads
   - Configure persistent storage

## References

- **Ansible:** https://docs.ansible.com/
- **KinD:** https://kind.sigs.k8s.io/
- **KubeEdge:** https://kubeedge.io/
- **ArgoCD:** https://argoproj.github.io/argo-cd/
- **ROS2:** https://docs.ros.org/

## Support

For issues with Ansible playbooks:
1. Check kubeconfig is accessible
2. Verify kubectl works: `kubectl get nodes`
3. Run with verbose: `ansible-playbook -vvv`
4. Check logs in respective namespaces
