# Deployment Options - Complete Guide

You now have **two complete, production-ready options** for deploying the robotics platform: Terraform or Ansible. Both deliver identical functionality.

## Quick Start

### Option 1: Terraform (IaC with State Management)

```bash
cd infra/environments/development/kind-local
terraform init
terraform apply
```

**Time:** ~10 minutes  
**Best for:** Production, multi-cloud, enterprise

### Option 2: Ansible (Simple YAML-based)

```bash
make kind-deploy
```

**Time:** ~8 minutes  
**Best for:** Local dev, ops teams, quick iteration

---

## Side-by-Side Comparison

### What Each Deploys

Both options deploy the **identical platform:**

```
┌─────────────────────────────────────────────────────┐
│         Robotics Automation Platform                │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │  Kubernetes Control Plane (KinD)            │  │
│  │  - 3 control plane nodes                    │  │
│  │  - 6 worker nodes                           │  │
│  │  - Cilium CNI + Hubble observability        │  │
│  │  - Metrics Server                           │  │
│  └─────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │  KubeEdge CloudCore (kubeedge namespace)    │  │
│  │  - WebSocket tunnel (port 10000)            │  │
│  │  - QUIC fast lane (port 10001)              │  │
│  │  - HTTPS secure channel (port 10002)        │  │
│  │  - MQTT EventBus (port 1883)                │  │
│  │  - Metrics endpoint (port 9000)             │  │
│  └─────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │  ArgoCD (argocd namespace)                  │  │
│  │  - GitOps workflow automation               │  │
│  │  - GitHub integration support               │  │
│  └─────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │  ROS2 Applications (default namespace)      │  │
│  │  - FastDDS Discovery Server (Domain 42)     │  │
│  │  - Talker + Listener (Domain 42, cloud)     │  │
│  │  - IoT Sensor (Domain 43, isolated)         │  │
│  │  - Multi-domain DDS network isolation       │  │
│  └─────────────────────────────────────────────┘  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Detailed Comparison

| Aspect | Terraform | Ansible |
|--------|-----------|---------|
| **Setup Time** | 5 min (init) | 2 min (no setup) |
| **Deployment Time** | 8-10 min | 8-10 min |
| **Configuration** | HCL | YAML |
| **State Management** | Built-in terraform.state | None (idempotent) |
| **Plan Preview** | `terraform plan` | No preview |
| **Learning Curve** | Moderate | Easy |
| **Debugging** | TF_LOG=DEBUG, terraform plan | ansible-playbook -vvv |
| **Modularity** | Native modules | Collections/roles |
| **Reusability** | Excellent | Good |
| **Multi-cloud** | Native support | Manual setup |
| **Team Best For** | Cloud engineers | DevOps/SRE |
| **Local Dev** | Good | Excellent |
| **Production** | Excellent | Limited* |

*Ansible is great for config management, Terraform better for infra provisioning.

---

## Decision Tree

```
Do you need state management?
├─ YES → Use Terraform
│  └─ terraform.state tracks all resources
│  └─ terraform plan shows changes before apply
│  └─ Team auditing/compliance needed
│
└─ NO → Use Ansible
   └─ Idempotent playbooks (safe to re-run)
   └─ No state file overhead
   └─ Fast iteration and debugging
   
Are you running in production?
├─ AWS/Cloud → Use Terraform
│  └─ Infrastructure as Code standard
│  └─ Multi-cloud capability
│  └─ State-based resource tracking
│
└─ Local/Dev → Use Ansible
   └─ Faster setup
   └─ Simpler for rapid changes
   
Team expertise?
├─ Cloud/IaC → Use Terraform
│  └─ Team knows HCL
│  └─ IaC best practices followed
│
└─ Ops/DevOps → Use Ansible
   └─ Team knows YAML
   └─ Configuration management background
```

---

## Documentation Guide

### For Terraform Users

1. **Quick Start** → `QUICKSTART.md`
2. **Architecture** → `ARCHITECTURE.md`
3. **KubeEdge Guide** → `KUBEEDGE_GUIDE.md`
4. **Implementation** → `IMPLEMENTATION_SUMMARY.md`
5. **Comparison** → `TERRAFORM_VS_ANSIBLE.md`

**Deploy:**
```bash
cd infra/environments/development/kind-local
terraform init
terraform apply
```

---

### For Ansible Users

1. **Quick Start** → `QUICKSTART_ANSIBLE.md`
2. **Detailed Guide** → `infra/ansible/README.md`
3. **Updates Summary** → `ANSIBLE_UPDATES.md`
4. **Comparison** → `TERRAFORM_VS_ANSIBLE.md`

**Deploy:**
```bash
make kind-deploy
# OR
cd infra/ansible && ansible-playbook playbooks/site.yml
```

---

### For Both

1. **Component Comparison** → This file
2. **Architecture Overview** → `ARCHITECTURE.md`
3. **KubeEdge Details** → `KUBEEDGE_GUIDE.md`
4. **Main README** → `README.md`

---

## What You Get

### Kubernetes Cluster
- **Type:** KinD (Kubernetes in Docker)
- **Control Planes:** 3 (configurable)
- **Worker Nodes:** 6 (configurable)
- **Kubernetes:** v1.29.2 (configurable)
- **CNI:** Cilium with Hubble
- **Monitoring:** Metrics Server

### Cloud-Edge Computing
- **KubeEdge CloudCore:** Manages edge nodes
- **Tunnels:** WebSocket, QUIC, HTTPS
- **Edge Messaging:** MQTT EventBus
- **Registration:** Automatic join script generation
- **Support:** Real devices and simulated nodes

### Container Orchestration
- **GitOps:** ArgoCD for automated deployments
- **GitHub Integration:** Pull-based sync
- **Application Management:** CRD-based
- **Multi-environment:** Overlay support

### Robotics Applications
- **ROS2:** Humble distribution
- **DDS:** FastDDS with discovery server
- **Multi-domain:** Domain isolation support
- **Communication:** Talker/Listener pattern
- **Isolation:** 2 domains (42 and 43)

---

## Common Tasks (Same for Both)

### View Cluster Status

```bash
# Nodes
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Services
kubectl get svc -A
```

### View Application Logs

```bash
# KubeEdge CloudCore
kubectl logs -f deployment/cloudcore -n kubeedge

# ROS2 Talker
kubectl logs -f deployment/ros2-talker-cloud

# ArgoCD
kubectl logs -f deployment/argocd-server -n argocd
```

### Port Forward for Access

```bash
# ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Then: https://localhost:8080
```

### Register Edge Node

```bash
# Get CloudCore IP
kubectl get svc cloudcore -n kubeedge

# Run join script on edge device
/tmp/join-edge-node.sh robot-edge-01 <cloudcore-ip> 10000

# Verify
kubectl get nodes -o wide
```

---

## Switching Between Options

### From Terraform to Ansible

```bash
# 1. Destroy Terraform deployment
make destroy

# 2. Deploy with Ansible
make kind-deploy

# Result: Same platform, different tool
```

### From Ansible to Terraform

```bash
# 1. Delete KinD cluster
kind delete cluster --name robotics-dev

# 2. Deploy with Terraform
cd infra/environments/development/kind-local
terraform init
terraform apply

# Result: Same platform, different tool
```

---

## Feature Parity Checklist

Both options deploy with feature parity:

### Infrastructure (100% Parity)
- [x] KinD cluster creation
- [x] Configurable control planes
- [x] Configurable workers
- [x] Cilium CNI
- [x] Hubble observability
- [x] Metrics Server
- [x] Port mappings

### KubeEdge (100% Parity)
- [x] CloudCore deployment
- [x] RBAC permissions
- [x] WebSocket tunnel
- [x] QUIC tunnel
- [x] HTTPS tunnel
- [x] MQTT EventBus
- [x] Self-signed certificates
- [x] Edge join script

### GitOps (100% Parity)
- [x] ArgoCD deployment
- [x] GitHub integration
- [x] Example applications
- [x] Initial password setup

### ROS2 (100% Parity)
- [x] FastDDS Discovery Server
- [x] ROS2 Talker/Listener
- [x] Multi-domain DDS
- [x] Domain isolation
- [x] Cloud deployments

---

## Next Steps

### Step 1: Choose Your Approach

**Terraform if:**
- Need state management
- Multi-cloud future
- Production infrastructure
- Team knows HCL

**Ansible if:**
- Local development
- Quick iteration
- Ops team prefers YAML
- No state needed

### Step 2: Deploy

**Terraform:**
```bash
cd infra/environments/development/kind-local
terraform init
terraform apply
```

**Ansible:**
```bash
make kind-deploy
```

### Step 3: Verify

```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
```

### Step 4: Explore

- Check ROS2 logs: `kubectl logs -f deployment/ros2-talker-cloud`
- Access ArgoCD: `kubectl port-forward -n argocd svc/argocd-server 8080:443`
- View KubeEdge: `kubectl get pods -n kubeedge`

---

## Troubleshooting

### Issue: Tools Not Installed

```bash
# Check all required tools
make versions

# Install missing tools
brew install terraform ansible kubectl kind helm
```

### Issue: Cluster Creation Fails

**Terraform:**
```bash
terraform plan  # See what would happen
terraform destroy  # Clean up
# Fix issues
terraform apply
```

**Ansible:**
```bash
ansible-playbook playbooks/site.yml -vvv  # Verbose output
kind delete cluster --name robotics-dev  # Clean up
# Fix issues
make kind-deploy
```

### Issue: Pods Not Starting

```bash
# Check events
kubectl get events -A

# Describe problematic pod
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>
```

---

## Performance Characteristics

Both deployments have identical performance:

```
Cluster Creation:     3-5 minutes
KubeEdge Deploy:      2-3 minutes
ArgoCD Deploy:        2-3 minutes
ROS2 Deploy:          1-2 minutes
─────────────────────────────────
Total Time:           8-10 minutes

Deployment Idempotent: Yes (both)
Resource Usage:        ~8GB RAM, ~15GB disk
CPU Cores Needed:      4+ recommended
```

---

## Support & Documentation

### Terraform
- Official docs: https://registry.terraform.io/
- KinD module: `infra/modules/kubernetes-cluster-kind/`
- KubeEdge module: `infra/modules/kubeedge-gateway/`
- Quick start: `QUICKSTART.md`

### Ansible
- Official docs: https://docs.ansible.com/
- Collection docs: `kubernetes.core`
- Playbooks: `infra/ansible/playbooks/`
- Quick start: `QUICKSTART_ANSIBLE.md`

### Both Platforms
- Architecture: `ARCHITECTURE.md`
- KubeEdge guide: `KUBEEDGE_GUIDE.md`
- Main docs: `README.md`

---

## Summary

| Tool | Time | Setup | State | Cloud | Local |
|------|------|-------|-------|-------|-------|
| **Terraform** | 10 min | 5 min | Yes | Excellent | Good |
| **Ansible** | 10 min | 2 min | No | Manual | Excellent |
| **Result** | Same | Same | Different | Same | Same |

Both deliver the complete robotics platform. Choose based on your team's preference and use case.

---

## Making Your Choice

**I choose Terraform because:**
- [ ] Need state management
- [ ] Multi-cloud deployment
- [ ] Production infrastructure
- [ ] Team knows HCL
- [ ] Need terraform plan

**I choose Ansible because:**
- [ ] Local development focus
- [ ] Prefer YAML configuration
- [ ] Ops team familiar with Ansible
- [ ] Rapid iteration needed
- [ ] No state complexity

Either way, you get the same powerful robotics platform ready for edge computing with ROS2, KubeEdge, and ArgoCD!
