# End-to-End Robotics Automation Platform

Complete infrastructure-as-code automation for deploying a production-grade Kubernetes cluster with KubeEdge and ROS 2 on AWS.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Infrastructure (Terraform)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              VPC (10.0.0.0/16)                           │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │  Kubernetes Control Plane (3 nodes)                │  │   │
│  │  │  - kube-apiserver                                   │  │   │
│  │  │  - etcd                                             │  │   │
│  │  │  - kube-scheduler                                   │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                        ▲                                    │   │
│  │  ┌────────────────────┴─────────────────────────────────┐  │   │
│  │  │  Worker Nodes (3+ nodes)                             │  │   │
│  │  │  - kubelet                                           │  │   │
│  │  │  - kube-proxy                                        │  │   │
│  │  │  - CNI (Cilium/Flannel)                              │  │   │
│  │  │  - ROS 2 Workloads                                   │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                            │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │  KubeEdge Gateway (Cloud)                          │  │   │
│  │  │  - CloudCore                                        │  │   │
│  │  │  - MQTT Broker                                      │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                      ▲                                     │   │
│  │                      │ (DDS + MQTT)                        │   │
│  └──────────────────────┼─────────────────────────────────┘   │   │
│                         │                                      │   │
│  ┌──────────────────────▼──────────────────────────────────┐  │   │
│  │           RDS Aurora PostgreSQL                         │  │   │
│  │  - High Availability (Multi-AZ)                         │  │   │
│  │  - Automated Backups                                    │  │   │
│  │  - Read Replicas                                        │  │   │
│  └──────────────────────────────────────────────────────────┘  │   │
│                                                                   │   │
└─────────────────────────────────────────────────────────────────┘   │
                                                                        │
                         Internet (Optional)                           │
                                │                                      │
                ┌───────────────┴────────────────┐                     │
                │                                │                     │
         ┌──────▼──────┐              ┌──────────▼──────┐              │
         │  Edge Node 1│              │  Edge Node N    │              │
         │  (KubeEdge) │              │  (KubeEdge)     │              │
         │  ROS 2 Pkg  │              │  ROS 2 Pkg      │              │
         │  Sensors    │              │  Sensors        │              │
         └─────────────┘              └─────────────────┘              │
```

## Components

### 1. Terraform Modules

#### a. `kubernetes-cluster` Module
Provisions the base Kubernetes infrastructure with:
- 3 Control Plane nodes (with high availability)
- 3+ Worker nodes (configurable)
- Security groups and network configuration
- Route53 DNS records for all nodes
- Network interfaces with fixed IPs

**Usage:**
```hcl
module "kubernetes_cluster" {
  source = "../../../modules/kubernetes-cluster"
  
  cluster_name       = "robotics-prod"
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  subnet_ids         = module.vpc.private_subnets
  control_plane_count = 3
  worker_node_count   = 3
  route53_zone_id    = aws_route53_zone.cluster.zone_id
  domain_name        = "robotics.local"
}
```

#### b. `kubeedge-gateway` Module
Deploys KubeEdge CloudCore with:
- Kubernetes deployment for CloudCore
- RBAC resources
- Service for external connectivity
- Configuration management

**Features:**
- Manages edge node registration
- Handles cloud-edge communication
- Supports MQTT for lightweight messaging
- Metrics collection

#### c. `ros2-deployment` Module
Deploys ROS 2 on Kubernetes with:
- DDS-enabled pods
- Service discovery via Kubernetes DNS
- Network policies for pod communication
- Horizontal Pod Autoscaler (optional)

**Features:**
- Pre-configured ROS 2 environment
- Multi-node ROS 2 deployments
- Liveness and readiness probes
- Resource limits and requests

### 2. Ansible Playbooks

#### a. `provision-control-plane.yml`
Initializes Kubernetes control plane nodes:
- System preparation (kernel modules, sysctl)
- Container runtime (Docker/containerd)
- Kubernetes components (kubeadm, kubelet, kubectl)
- kubeadm cluster initialization
- High availability setup with etcd clustering

#### b. `provision-worker-nodes.yml`
Prepares worker nodes:
- Container runtime setup
- Kubernetes components installation
- Joining to cluster
- Node labeling and configuration

#### c. `deploy-cni.yml`
Deploys Container Network Interface:
- Cilium (recommended for performance)
- Flannel (lightweight alternative)
- Network policy support

#### d. `deploy-kubeedge.yml`
Deploys KubeEdge infrastructure:
- CloudCore initialization
- Edge token generation
- Edge node join scripts

#### e. `deploy-ros2.yml`
Deploys ROS 2 workloads:
- ROS 2 namespace creation
- Pod deployment with DDS configuration
- Service creation for inter-pod communication
- Health checks and monitoring

## Deployment Workflow

### Phase 1: Infrastructure Provisioning (Terraform)

```bash
cd infra/environments/development/robotics-prod

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply infrastructure
terraform apply
```

**Outputs:**
- Cluster endpoint
- Control plane IPs
- Worker node IPs
- Ansible inventory file
- kubeconfig

### Phase 2: Cluster Setup (Ansible)

```bash
cd infra/ansible

# Update inventory with Terraform outputs
export TF_OUTPUT=$(cd ../environments/development/robotics-prod && terraform output -json)

# Run provisioning playbooks
ansible-playbook playbooks/provision-control-plane.yml
ansible-playbook playbooks/provision-worker-nodes.yml
ansible-playbook playbooks/deploy-cni.yml
```

### Phase 3: Kubernetes Stack (Terraform + Ansible)

```bash
# Deploy KubeEdge and ROS 2
terraform apply -target=module.kubeedge_gateway
terraform apply -target=module.ros2_deployment

# Or via Ansible
ansible-playbook playbooks/deploy-kubeedge.yml
ansible-playbook playbooks/deploy-ros2.yml
```

### Phase 4: Edge Node Setup (Ansible)

```bash
# Deploy to edge nodes
ansible-playbook playbooks/deploy-edge-nodes.yml -i inventory-edge.yml
```

## Configuration

### Terraform Variables

**Cluster Configuration:**
```hcl
cluster_name           = "robotics-prod"      # Cluster identifier
cluster_domain         = "robotics.local"     # DNS domain
vpc_cidr              = "10.0.0.0/16"         # VPC CIDR block
control_plane_count   = 3                     # HA setup
worker_node_count     = 3                     # Min workers
```

**ROS 2 Configuration:**
```hcl
ros2_image            = "osrf/ros:humble-desktop"
ros2_replicas         = 2
ros_domain_id         = "0"
ros2_cpu_limit        = "1000m"
ros2_memory_limit     = "1Gi"
ros2_enable_autoscaling = true
ros2_max_replicas     = 5
```

**KubeEdge Configuration:**
```hcl
kubeedge_cloudcore_image = "kubeedge/cloudcore:1.14.0"
kubeedge_replicas        = 1
```

### Ansible Variables

Update `infra/ansible/inventory.yml`:
```yaml
k8s_control_plane:
  hosts:
    k8s-cp-1:
      ansible_host: 10.0.0.10
      private_ip: 10.0.0.10

k8s_workers:
  hosts:
    k8s-worker-1:
      ansible_host: 10.0.0.50
```

## Monitoring & Observability

### Prometheus & Grafana
```bash
kubectl apply -f monitoring/prometheus-operator.yaml
kubectl apply -f monitoring/grafana-dashboards.yaml
```

### KubeEdge Metrics
```bash
kubectl logs -n kubeedge -l app=cloudcore
```

### ROS 2 Monitoring
```bash
# List ROS 2 nodes
kubectl exec -it <pod> -n ros2-workloads -- ros2 node list

# Monitor topics
kubectl exec -it <pod> -n ros2-workloads -- ros2 topic list
```

## Networking

### DDS Configuration
ROS 2 uses DDS for inter-process communication:
- **Multicast ports:** 7400, 7401 (UDP)
- **Domain ID:** Configurable (default: 0)
- **Network policies:** Restrict to pod CIDR

### Edge-Cloud Communication
KubeEdge uses:
- **WebSocket:** Port 10000 (edge to cloud)
- **QUIC:** Port 10001 (UDP, low latency)
- **HTTPS:** Port 10002 (secure)

## Troubleshooting

### Cluster Issues

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check control plane
kubectl get pods -n kube-system

# View logs
kubectl logs -n kube-system -l component=kubelet
```

### KubeEdge Issues

```bash
# Check CloudCore
kubectl get pods -n kubeedge
kubectl logs -n kubeedge -l app=cloudcore

# Check edge nodes
keadm gettoken
```

### ROS 2 Issues

```bash
# Check pod logs
kubectl logs -n ros2-workloads -l app=ros2-workload

# Test ROS 2 environment
kubectl exec -it <pod> -n ros2-workloads -- bash
source /opt/ros/humble/setup.bash
ros2 node list
```

## Performance Tuning

### Control Plane
```yaml
# In kubeadm config
apiServer:
  extraArgs:
    max-requests-inflight: 3000
    max-mutating-requests-inflight: 1000
etcd:
  extraArgs:
    heartbeat-interval: 100
    election-timeout: 1000
```

### Worker Nodes
```bash
# Tune kernel parameters
sysctl -w net.core.somaxconn=65535
sysctl -w net.ipv4.tcp_max_syn_backlog=65535
sysctl -w vm.max_map_count=262144
```

### ROS 2 DDS
```bash
export ROS_DISCOVERY_SERVER=<ip>:<port>
export ROS_SUPER_CLIENT=true
```

## Security

### RBAC
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ros2-access
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch"]
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ros2-network-policy
  namespace: ros2-workloads
spec:
  podSelector:
    matchLabels:
      app: ros2-workload
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ros2-workload
    ports:
    - protocol: UDP
      port: 7400
```

### Encryption
- **Control plane to nodes:** TLS
- **Pod to pod:** Cilium encryption
- **Edge to cloud:** QUIC + TLS

## Scaling

### Horizontal Scaling (Add Worker Nodes)

```bash
# Update Terraform
terraform apply -var="worker_node_count=5"

# Join new nodes
ansible-playbook playbooks/provision-worker-nodes.yml -l k8s-worker-4,k8s-worker-5
```

### ROS 2 Pod Scaling

```bash
# Manual scaling
kubectl scale deployment ros2-node --replicas=5 -n ros2-workloads

# Or enable HPA
kubectl apply -f ros2-hpa.yaml
```

### KubeEdge Edge Nodes

```bash
# Register new edge node
keadm join \
  --cloudcore-ipport=<ip>:10000 \
  --edgenode-name=edge-node-2 \
  --token=<token>
```

## Backup & Recovery

### Cluster Backup

```bash
# Backup etcd
kubectl exec -n kube-system etcd-<node> -- etcdctl snapshot save /tmp/backup.db
```

### RDS Backup

```bash
# Automatic backups are configured
# Manual snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier robotics-prod \
  --db-cluster-snapshot-identifier robotics-backup-$(date +%s)
```

## Cleanup

### Destroy Everything

```bash
# Destroy ROS 2 workloads
terraform destroy -target=module.ros2_deployment

# Destroy KubeEdge
terraform destroy -target=module.kubeedge_gateway

# Destroy entire infrastructure
terraform destroy
```

## Cost Optimization

1. **Use SPOT instances** for worker nodes (20-80% savings)
2. **RDS Savings Plans** for database (14-42% savings)
3. **Reserved capacity** for control plane
4. **Auto-scaling policies** to match demand

## Advanced Topics

### Custom ROS 2 Packages
Create custom Docker images with your ROS 2 packages:
```dockerfile
FROM osrf/ros:humble-desktop
RUN apt-get update && \
    apt-get install -y ros-humble-your-package
```

### Edge Device Types
Supported edge node platforms:
- ARM64 (Raspberry Pi 4, Jetson Nano)
- x86_64 (Generic servers)
- ARM32 (IoT devices with 2GB+ RAM)

### CI/CD Integration
```yaml
# GitLab CI example
deploy_robotics:
  stage: deploy
  script:
    - cd infra/environments/development/robotics-prod
    - terraform apply -auto-approve
    - ansible-playbook -i inventory playbooks/deploy-ros2.yml
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [KubeEdge Project](https://kubeedge.io/)
- [ROS 2 Documentation](https://docs.ros.org/en/humble/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)

## Support

For issues and questions:
1. Check logs: `kubectl logs`, `journalctl`, Ansible output
2. Review configuration files
3. Consult respective project documentation
4. Open GitHub issues with detailed reproduction steps

---

**Version:** 1.0  
**Last Updated:** November 2025  
**Maintained By:** Infrastructure Team
