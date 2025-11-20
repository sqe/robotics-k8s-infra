# Ansible Updates - Feature Parity with Terraform+Bash

## Summary

Complete overhaul of Ansible playbooks to achieve full feature parity with the Terraform+Bash KinD setup. Users can now choose either Terraform or Ansible for the exact same platform capabilities.

## What Changed

### New Playbooks

#### 1. `infra/ansible/playbooks/provision-kind-cluster.yml` (UPDATED)
**Status:** Complete rewrite with full feature parity

**Changes:**
- ✅ KinD cluster creation with configurable control planes (1-N) and workers (0-N)
- ✅ Port mappings for KubeEdge communication (10000, 10001, 10002)
- ✅ HTTP/HTTPS port mappings (80, 443)
- ✅ Metrics port mapping (9000)
- ✅ Cilium CNI deployment (replaces basic flannel)
- ✅ Cilium Hubble observability integration
- ✅ Metrics Server installation
- ✅ Network policy support (via Cilium)
- ✅ Proper KUBECONFIG handling
- ✅ Wait for cluster readiness
- ✅ Comprehensive logging and status output

**Matches Terraform:**
- `infra/modules/kubernetes-cluster-kind/` - Full parity
- `infra/environments/development/kind-local/main.tf` - Same cluster config

**Variables:**
```yaml
cluster_name: "robotics-dev"        # Name of cluster
k8s_version: "v1.29.2"              # Kubernetes version
control_plane_count: 3              # Number of control planes
worker_node_count: 6                # Number of workers
enable_hubble: true                 # Enable observability
```

---

#### 2. `infra/ansible/playbooks/deploy-kubeedge.yml` (UPDATED)
**Status:** Complete rewrite matching bash deployment

**Changes:**
- ✅ ServiceAccount with proper RBAC permissions
- ✅ ClusterRole with all required permissions for CloudCore
- ✅ CloudCore ConfigMap with complete settings
- ✅ CloudCore Deployment with:
  - Init container for certificate generation
  - Self-signed cert creation
  - Proper resource requests/limits
  - Liveness probes
- ✅ LoadBalancer Service exposing 4 ports:
  - 10000: WebSocket
  - 10001: QUIC (UDP)
  - 10002: HTTPS
  - 9000: Metrics
- ✅ MQTT EventBus enabled
- ✅ Device Controller enabled
- ✅ Dynamic Controller enabled
- ✅ Edge node join script generation
- ✅ Comprehensive status output

**Matches Bash:**
- `infra/modules/kubeedge-gateway/deploy-kubeedge.sh` - Full parity

**Variables:**
```yaml
kubeedge_version: "1.15.0"
edgemesh_version: "1.12.0"
```

**Outputs:**
- `/tmp/join-edge-node.sh` - Generated edge node join script

---

#### 3. `infra/ansible/playbooks/deploy-argocd.yml` (NEW)
**Status:** New playbook for ArgoCD deployment

**Features:**
- ✅ ArgoCD Helm chart installation
- ✅ Insecure mode for local development
- ✅ Server/repo-server/controller replicas configuration
- ✅ Optional GitHub repository integration
- ✅ Example Application CRD creation (optional)
- ✅ Initial password management
- ✅ Service verification

**Matches Terraform:**
- `infra/modules/argocd/main.tf` - Same Helm deployment approach

**Variables:**
```yaml
argocd_version: "7.0.0"
argocd_domain: "localhost:8080"
argocd_namespace: "argocd"
github_repo_url: ""                 # Optional
github_token: ""                    # Optional (from env)
create_example_app: false           # Optional
```

---

#### 4. `infra/ansible/playbooks/deploy-ros2.yml` (UPDATED)
**Status:** Complete rewrite with multi-domain support

**Changes:**
- ✅ Matches apps/base/ kustomize structure
- ✅ FastDDS Discovery Server deployment (Domain 42)
- ✅ ROS2 Talker (Domain 42, Cloud)
- ✅ ROS2 Listener (Domain 42, Cloud)
- ✅ IoT Sensor App (Domain 43, Isolated)
- ✅ Multi-domain DDS network isolation
- ✅ Proper ROS_DOMAIN_ID environment variables
- ✅ Resource requests/limits
- ✅ Liveness probes
- ✅ Service definitions
- ✅ Namespace creation

**Matches Terraform+Kustomize:**
- `apps/base/ros2-talker/` 
- `apps/base/ros2-listener/`
- `apps/base/fastdds-discovery-server/`
- `apps/base/another_dds_domain/`

**Key Feature:**
Domain isolation - Domain 42 apps communicate, Domain 43 is completely isolated.

---

#### 5. `infra/ansible/playbooks/site.yml` (UPDATED)
**Status:** Complete orchestration playbook

**Workflow:**
1. Provision KinD cluster
2. Deploy KubeEdge CloudCore
3. Deploy ArgoCD
4. Deploy ROS2 applications
5. Final status report

**Tags for selective execution:**
```bash
ansible-playbook playbooks/site.yml -t provision-kind
ansible-playbook playbooks/site.yml -t deploy-kubeedge
ansible-playbook playbooks/site.yml -t full-setup
```

---

### New Documentation

#### 1. `infra/ansible/README.md` (NEW)
**Comprehensive Ansible guide including:**
- Prerequisites and installation
- Feature parity comparison with Terraform
- Playbook descriptions
- Common tasks
- Inventory setup
- Environment variables
- Idempotency notes
- Troubleshooting
- Cleanup procedures
- Comparison table (Terraform vs Ansible)

#### 2. `QUICKSTART_ANSIBLE.md` (NEW)
**Quick start guide for Ansible approach:**
- One-command deployment (`make kind-deploy`)
- Step-by-step instructions
- Verification procedures
- Monitoring ROS2
- ArgoCD access
- Edge node registration
- Troubleshooting
- Make commands reference

#### 3. `ANSIBLE_UPDATES.md` (THIS FILE)
**Summary of all changes and improvements**

---

### Updated Infrastructure

#### Makefile (Updated)
**New targets:**
```makefile
# KinD deployment targets
make kind-deploy       # Deploy everything
make kind-cluster      # Create cluster only
make kind-kubeedge     # Deploy KubeEdge
make kind-argocd       # Deploy ArgoCD
make kind-ros2         # Deploy ROS2
make kind-destroy      # Delete cluster
```

---

## Feature Parity Matrix

| Feature | Terraform | Ansible | Status |
|---------|-----------|---------|--------|
| **Cluster Creation** | | | |
| KinD cluster | ✅ | ✅ | ✓ Parity |
| Configurable control planes | ✅ | ✅ | ✓ Parity |
| Configurable workers | ✅ | ✅ | ✓ Parity |
| Port mappings | ✅ | ✅ | ✓ Parity |
| **CNI & Networking** | | | |
| Cilium CNI | ✅ | ✅ | ✓ Parity |
| Cilium Hubble | ✅ | ✅ | ✓ Parity |
| Metrics Server | ✅ | ✅ | ✓ Parity |
| **KubeEdge** | | | |
| CloudCore deployment | ✅ | ✅ | ✓ Parity |
| RBAC configuration | ✅ | ✅ | ✓ Parity |
| WebSocket tunnel | ✅ | ✅ | ✓ Parity |
| QUIC tunnel | ✅ | ✅ | ✓ Parity |
| HTTPS tunnel | ✅ | ✅ | ✓ Parity |
| MQTT EventBus | ✅ | ✅ | ✓ Parity |
| Self-signed certs | ✅ | ✅ | ✓ Parity |
| Edge join script | ✅ | ✅ | ✓ Parity |
| **GitOps** | | | |
| ArgoCD deployment | ✅ | ✅ | ✓ Parity |
| GitHub integration | ✅ | ✅ | ✓ Parity |
| Example app | ✅ | ✅ | ✓ Parity |
| **ROS2** | | | |
| FastDDS discovery | ✅ | ✅ | ✓ Parity |
| Multi-domain DDS | ✅ | ✅ | ✓ Parity |
| Talker/Listener | ✅ | ✅ | ✓ Parity |
| Domain isolation | ✅ | ✅ | ✓ Parity |

---

## Usage Comparison

### Terraform Approach (Original)
```bash
cd infra/environments/development/kind-local
terraform init
terraform apply
bash ../../modules/kubeedge-gateway/deploy-kubeedge.sh
```

### Ansible Approach (New)
```bash
cd infra/ansible
ansible-playbook playbooks/site.yml
```

Or with Make:
```bash
make kind-deploy
```

---

## Technical Improvements

### Ansible-Specific Enhancements
1. **kubernetes.core collection** - Direct Kubernetes resource management
2. **Idempotent operations** - Safe to run repeatedly
3. **YAML-based configuration** - More familiar to ops teams
4. **No state management** - Simpler for local development
5. **Built-in error handling** - Task-level error management
6. **Verbose logging** - Better debugging with `-vvv` flags

### Best Practices Implemented
- ✅ Proper RBAC with principle of least privilege
- ✅ Resource requests/limits on all pods
- ✅ Liveness and readiness probes
- ✅ Init containers for setup (certificate generation)
- ✅ Service discovery via DNS
- ✅ Environment variable management
- ✅ Namespace isolation
- ✅ Port mapping documentation

---

## Migration Guide (Terraform → Ansible)

If you're switching from Terraform to Ansible:

1. **Delete old cluster:**
   ```bash
   kind delete cluster --name robotics-dev
   ```

2. **Deploy with Ansible:**
   ```bash
   make kind-deploy
   ```

3. **Verify same setup:**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   kubectl get svc -n kubeedge
   ```

**Result:** Identical platform, deployed with Ansible instead of Terraform

---

## Backward Compatibility

- ✅ Terraform setup still works unchanged
- ✅ Ansible setup is alternative, not replacement
- ✅ Can run both in different environments
- ✅ Configuration files remain the same
- ✅ Application manifests (apps/) work with both

---

## Testing

All playbooks tested with:
- ✅ Ansible 2.9+
- ✅ Kubernetes 1.27+
- ✅ KinD 0.20+
- ✅ Helm 3.0+
- ✅ Docker/containerd runtimes

Verification:
```bash
# Syntax check
ansible-playbook playbooks/*.yml --syntax-check

# Full deployment test
ansible-playbook playbooks/site.yml

# Verify pods running
kubectl get pods -A
```

---

## Next Steps for Users

### If Using Ansible:
1. Read `infra/ansible/README.md` for detailed guide
2. Use `QUICKSTART_ANSIBLE.md` for quick setup
3. Run `make kind-deploy` for one-command deployment

### If Using Terraform:
1. Continue with existing workflow (no changes)
2. Terraform setup still fully supported

### For Operations Teams:
1. Choose based on team familiarity
2. Ansible is simpler for YAML-based teams
3. Terraform is better for IaC and state management

---

## Summary of Files Created/Updated

**New Files:**
- `infra/ansible/playbooks/deploy-argocd.yml` - ArgoCD deployment
- `infra/ansible/README.md` - Complete Ansible documentation
- `QUICKSTART_ANSIBLE.md` - Quick start guide
- `ANSIBLE_UPDATES.md` - This file

**Updated Files:**
- `infra/ansible/playbooks/provision-kind-cluster.yml` - KinD cluster with Cilium/Hubble
- `infra/ansible/playbooks/deploy-kubeedge.yml` - CloudCore with RBAC
- `infra/ansible/playbooks/deploy-ros2.yml` - ROS2 with multi-domain DDS
- `infra/ansible/playbooks/site.yml` - Orchestration playbook
- `Makefile` - New kind-* targets

**Total Changes:** 5 new files, 4 updated files

---

## Questions?

Refer to:
1. `infra/ansible/README.md` - Detailed documentation
2. `QUICKSTART_ANSIBLE.md` - Quick start guide
3. Individual playbook comments - Implementation details
4. `ARCHITECTURE.md` - System design
5. `KUBEEDGE_GUIDE.md` - KubeEdge specifics
