# Cloud-Edge Robotics Automation Platform

Production-grade infrastructure automation for deploying containerized robotics applications on Kubernetes with cloud-edge computing via KubeEdge and ROS 2.

## Overview

This platform provides a complete solution for:
- Provisioning Kubernetes clusters (local kind or AWS)
- Managing edge nodes via KubeEdge CloudCore
- Running ROS 2 workloads on cloud and edge
- Multi-domain DDS support for robotics communication
- GitOps-based deployment via ArgoCD

## Architecture

```
┌─────────────────────────────┐
│  Kubernetes Control Plane   │
│  - KubeEdge CloudCore       │
│  - ArgoCD                   │
│  - ROS2 Publishers/Subs     │
└─────────────────────────────┘
         ▲    ▲    ▲
    WebSocket  QUIC  HTTPS
         │    │    │
┌────────┴────┴────┴────────┐
│  Edge Nodes (KubeEdge)     │
│  - Robots, IoT devices     │
│  - Local ROS2              │
│  - Real-time processing    │
└────────────────────────────┘
```

## Quick Start

### Prerequisites

```bash
# Verify installed tools
kubectl version --client          # >= 1.28
kind version                       # >= 0.20
terraform --version               # >= 1.0
python3 --version                 # >= 3.8
```

### Deploy Local Cluster

```bash
# Create kind cluster with Terraform
cd infra/environments/development/kind-local
terraform init
terraform apply

# Deploy KubeEdge CloudCore
cd ../../modules/kubeedge-gateway
bash deploy-kubeedge.sh

# Verify
python3 edge-node-manager.py status
```

### Simulate Edge Node with ROS2

```bash
# Create edge node simulation (pod-based)
python3 edge-node-manager.py simulate-edge \
  --node-name robot-edge-01 \
  --worker-node robotics-dev-worker \
  --domain-id 42

# View ROS2 messages
kubectl logs -f deployment/ros2-talker-edge -c talker
```

Expected output:
```
[INFO] [1763636906.911529887] [talker]: Publishing: 'Hello World: 612'
[INFO] [1763636907.911371679] [talker]: Publishing: 'Hello World: 613'
```

## Project Structure

```
infra/
├── modules/
│   ├── kubeedge-gateway/          # Edge computing layer
│   │   ├── deploy-kubeedge.sh     # CloudCore deployment
│   │   ├── edge-node-manager.py   # CLI for edge management
│   │   └── simulate-edge-node.sh  # Edge node simulation
│   ├── kubernetes-cluster-kind/   # Kind cluster provisioning
│   ├── argocd/                    # GitOps setup
│   └── rds-aurora-pg/             # Database
│
├── environments/
│   └── development/
│       ├── kind-local/            # Local development cluster
│       └── dev-001/               # AWS development setup
│
└── ansible/                       # Provisioning playbooks

apps/
├── base/                          # Base ROS2 app configs
│   ├── ros2-talker/
│   ├── ros2-listener/
│   ├── fastdds-discovery-server/
│   ├── another_dds_domain/        # Multi-domain example (domain 43)
│   └── ...
│
├── applications/                  # ArgoCD Application CRDs
│   ├── core-apps.yaml
│   └── ros2-apps.yaml
│
└── overlays/                      # Environment-specific patches
    └── development/
```

## Key Components

### KubeEdge CloudCore
Manages cloud-edge communication:
- WebSocket tunnel (port 10000)
- QUIC fast lane (port 10001)
- HTTPS secure channel (port 10002)

Deploy:
```bash
cd infra/modules/kubeedge-gateway
bash deploy-kubeedge.sh
```

### ROS2 Platform
Multi-domain DDS support with automatic discovery:
- Domain 42: Main robotics stack (fastdds-discovery-server + talker/listener)
- Domain 43: IoT sensors (another_dds_domain)

Deploy all:
```bash
kubectl apply -k apps/base/
```

### Edge Node Management
CLI tool for edge operations:
```bash
python3 edge-node-manager.py --help

# Available commands:
# - status: Show CloudCore and edge nodes
# - simulate-edge: Create pod-based edge simulation
# - deploy-ros2: Generate ROS2 deployment YAML
# - list: List registered edge nodes
# - join-script: Generate edge node join script
```

## Common Tasks

### Deploy ROS2 Apps

```bash
# Deploy to cloud (control plane)
kubectl apply -k apps/base/ros2-talker

# Deploy to edge node (real device)
python3 edge-node-manager.py deploy-ros2 \
  --app-name ros2-talker \
  --image arm64v8/ros:humble \
  --domain-id 42 \
  --output talker-edge.yaml

kubectl apply -f talker-edge.yaml
```

### Register Real Edge Device

```bash
# On edge device (Raspberry Pi, Jetson, etc.)
keadm join --cloudcore-ipport=<CLOUDCORE-IP>:10000 \
  --edgenode-name=warehouse-robot-01 \
  --kubeedge-version=v1.15.0

# Verify on control plane
kubectl get nodes -o wide
```

### Multi-Domain ROS2

```bash
# Domain 42 (talker/listener pair)
kubectl get pods -l ros-domain=42

# Domain 43 (separate from domain 42)
kubectl get pods -l ros-domain=43

# Different domains do NOT see each other's messages
# This isolates applications by domain
```

### Monitor Cluster

```bash
# All pods
kubectl get pods -A -o wide

# Edge nodes only (real KubeEdge)
kubectl get nodes -o wide | grep -i edge

# CloudCore status
kubectl get pods -n kubeedge
kubectl logs -f deployment/cloudcore -n kubeedge

# Metrics
kubectl top nodes
kubectl top pods -A
```

### Cleanup

```bash
# Delete edge simulation
kubectl delete pod robot-edge-01
kubectl delete deployment ros2-talker-edge

# Unregister real edge device (on edge device)
keadm reset --server=<CLOUDCORE-IP>:10000

# Delete from cluster
kubectl delete node <edge-node-name>
```

## Networking

### Required Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 10000 | WebSocket | Cloud-edge tunnel |
| 10001 | QUIC (UDP) | Fast tunnel |
| 10002 | HTTPS (TCP) | Secure tunnel |
| 1883 | TCP | MQTT broker |
| 9000 | TCP | Metrics |

### Firewall Setup (AWS)

```bash
# Allow edge devices to connect to CloudCore
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 10000 \
  --cidr 0.0.0.0/0
```

## Understanding Edge Simulation vs Real Nodes

### Simulated Edge (What We Built)

Kubernetes pods on control plane simulating edge:
```bash
python3 edge-node-manager.py simulate-edge

# Creates:
# - robot-edge-01 (pod - represents edge device)
# - ros2-talker-edge (deployment - ROS2 publisher)

# View: kubectl get pods -o wide
# Does NOT appear in: kubectl get nodes
```

Use for: Testing, development, demos

### Real Edge Nodes (Production)

Physical devices running KubeEdge EdgeCore:
```bash
keadm join --cloudcore-ipport=<IP>:10000 \
  --edgenode-name=warehouse-robot-01

# View: kubectl get nodes -o wide
# Appears with: kubectl describe node warehouse-robot-01
```

Use for: Production robotics, real devices, offline capability

## Troubleshooting

### CloudCore Won't Start
```bash
# Check logs
kubectl logs deployment/cloudcore -n kubeedge

# Common issues:
# - RBAC permissions (check clusterrole)
# - Resource limits (check requests/limits)
# - Config errors (check cloudcore.yaml)
```

### Edge Node Can't Connect
```bash
# Test connectivity from edge device
telnet <CLOUDCORE-IP> 10000

# Check firewall allows ports 10000-10002
# Check DNS resolves cloudcore.kubeedge.svc.cluster.local
```

### ROS2 Not Communicating
```bash
# Verify ROS_DOMAIN_ID matches
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].env[?(@.name=="ROS_DOMAIN_ID")].value}'

# Check FastDDS discovery server
kubectl get pods | grep discovery

# Different domain IDs won't communicate
```

## Deployment Workflows

### Local Development
```bash
cd infra/environments/development/kind-local
terraform apply

cd ../../modules/kubeedge-gateway
bash deploy-kubeedge.sh

python3 edge-node-manager.py simulate-edge
```

### AWS Production
```bash
# Create EKS cluster
cd infra/environments/development/robotics-prod
terraform apply

# Deploy KubeEdge CloudCore
bash ../../../modules/kubeedge-gateway/deploy-kubeedge.sh

# Register edge devices
keadm join --cloudcore-ipport=<NLB-IP>:10000 ...
```

## Features

Core Platform:
- KubeEdge CloudCore with WebSocket/QUIC/HTTPS
- ROS 2 support (DDS-enabled)
- Multi-domain network isolation
- Edge node registration and management
- ArgoCD for GitOps

Infrastructure:
- Terraform IaC for AWS
- Kind clusters for local development
- Ansible playbooks for provisioning
- Container runtime (Docker/containerd)
- Network policies and security

Operations:
- CLI tool for edge management
- Comprehensive logging
- Resource monitoring
- Health checks on deployments
- Easy cleanup and scaling

## Documentation

Detailed guides for specific topics:
- **KUBEEDGE_GUIDE.md** - Edge computing setup and management
- **ARCHITECTURE.md** - System design and component details
- **IMPLEMENTATION_SUMMARY.md** - What was built and how

## API & Commands

### Edge Node Manager CLI

```bash
# Status of platform
python3 edge-node-manager.py status

# Simulate edge node with ROS2
python3 edge-node-manager.py simulate-edge \
  --node-name robot-01 \
  --worker-node robotics-dev-worker \
  --domain-id 42

# Deploy ROS2 app
python3 edge-node-manager.py deploy-ros2 \
  --app-name ros2-talker \
  --image arm64v8/ros:humble \
  --domain-id 42
```

### Kubernetes Resources

```bash
# All resources
kubectl api-resources

# KubeEdge specific
kubectl api-resources | grep kubeedge

# ROS2 configurations
kubectl get configmaps
kubectl get secrets
```

## Performance

Typical deployment times:
- CloudCore initialization: 2-3 minutes
- Edge node registration: 30-60 seconds
- ROS2 pod startup: 5-10 seconds
- Message latency (cloud-edge): 50-200ms

## Cost Estimation

Local (kind):
- Free (uses host resources)

AWS EKS:
- Control plane: ~$73/month
- Worker nodes (3x t4g.large): ~$50/month
- CloudCore: Free (runs on workers)
- RDS (optional): ~$100/month

## Support & Community

- KubeEdge: https://kubeedge.io
- ROS2: https://docs.ros.org
- Kubernetes: https://kubernetes.io
- GitHub Issues: File issues in this repo

## Contributing

1. Test changes locally with kind
2. Update relevant documentation
3. Submit pull request with clear description
4. Ensure all tests pass

## License

[Specify your license]

---

Built for the robotics and edge computing community. Last updated: November 2025.

For quick setup, see Quick Start above. For detailed information, refer to KUBEEDGE_GUIDE.md and ARCHITECTURE.md.
