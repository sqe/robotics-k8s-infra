# Terraform vs Ansible - Platform Deployment Guide

Both Terraform and Ansible can now deploy the identical robotics platform. This guide helps you choose the right approach for your use case.

## Quick Decision Matrix

| Scenario | Recommendation |
|----------|-----------------|
| Local development, just need quick cluster | **Ansible** |
| Team knows Ansible well | **Ansible** |
| Need state management, multi-cloud | **Terraform** |
| Team knows Terraform well | **Terraform** |
| Production AWS deployment | **Terraform** |
| Simple, repeateable local setup | **Ansible** |
| Infrastructure as Code best practices | **Terraform** |
| Ops team, YAML-friendly | **Ansible** |

## Detailed Comparison

### Terraform Approach

**File Structure:**
```
infra/
├── environments/development/kind-local/
│   ├── main.tf              # Main configuration
│   ├── variables.tf         # Input variables
│   └── terraform.tfvars     # Variable values
├── modules/
│   ├── kubernetes-cluster-kind/    # KinD module
│   ├── argocd/                     # ArgoCD module
│   └── kubeedge-gateway/           # KubeEdge scripts
└── scripts/
    └── deploy-kubeedge.sh          # Bash script
```

**Pros:**
- ✅ Built-in state management (`terraform.state`)
- ✅ `terraform plan` shows exact changes before applying
- ✅ Modular structure with reusable modules
- ✅ Multi-cloud support (AWS, GCP, Azure, etc.)
- ✅ Version control friendly
- ✅ Professional IaC standard
- ✅ Detailed plan diffs
- ✅ Destroy with confidence (state tracked)
- ✅ Excellent for production
- ✅ HCL is powerful and expressive

**Cons:**
- ❌ Requires learning HCL (HashiCorp Configuration Language)
- ❌ State file must be managed carefully
- ❌ Larger learning curve for ops teams
- ❌ State lock conflicts in teams
- ❌ Local state files need backups
- ❌ Setup time (init, plan, apply)
- ❌ More complex for simple setups

**Installation:**
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.0.0/terraform_1.0.0_linux_amd64.zip
unzip terraform_1.0.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Deployment:**
```bash
cd infra/environments/development/kind-local
terraform init
terraform plan
terraform apply
```

**Documentation:**
- See `QUICKSTART.md`
- Detailed: `ARCHITECTURE.md`
- KubeEdge: `KUBEEDGE_GUIDE.md`

---

### Ansible Approach

**File Structure:**
```
infra/
└── ansible/
    ├── playbooks/
    │   ├── provision-kind-cluster.yml    # KinD creation
    │   ├── deploy-kubeedge.yml           # KubeEdge
    │   ├── deploy-argocd.yml             # ArgoCD
    │   ├── deploy-ros2.yml               # ROS2 apps
    │   └── site.yml                      # Orchestration
    ├── inventory.yml                     # Host inventory
    └── README.md                         # Documentation
```

**Pros:**
- ✅ Simple YAML-based configuration
- ✅ No state file to manage
- ✅ Idempotent (safe to run repeatedly)
- ✅ Familiar to ops/DevOps teams
- ✅ Lower learning curve
- ✅ Great for local development
- ✅ Quick setup and deployment
- ✅ Direct Kubernetes integration (kubernetes.core collection)
- ✅ Better for rapid prototyping
- ✅ No state lock issues

**Cons:**
- ❌ No state tracking (can't see what will change)
- ❌ No `plan` equivalent
- ❌ Harder for production infrastructure management
- ❌ No rollback mechanism
- ❌ Less suitable for multi-cloud
- ❌ Idempotency depends on playbook design
- ❌ No drift detection (terraform plan-like)
- ❌ Better for config management than infrastructure

**Installation:**
```bash
# macOS
brew install ansible

# Linux/all
pip install ansible

# Install collections
ansible-galaxy collection install kubernetes.core
```

**Deployment:**
```bash
# One command
make kind-deploy

# Or step by step
cd infra/ansible
ansible-playbook playbooks/site.yml
```

**Documentation:**
- Quick start: `QUICKSTART_ANSIBLE.md`
- Detailed: `infra/ansible/README.md`
- Updates: `ANSIBLE_UPDATES.md`

---

## Feature Comparison

### Core Features

| Feature | Terraform | Ansible |
|---------|-----------|---------|
| **Configuration Language** | HCL | YAML |
| **State Management** | Built-in | None (idempotent) |
| **Plan Capability** | Yes | No |
| **Dry Run** | Yes (plan) | Limited |
| **Rollback** | Via state | Manual |
| **Drift Detection** | Yes | No |
| **Modules/Reusability** | Native modules | Collections |
| **Learning Curve** | Moderate | Easy |

### Platform Deployment

| Feature | Terraform | Ansible |
|---------|-----------|---------|
| **KinD Cluster** | ✅ | ✅ |
| **Cilium CNI** | ✅ | ✅ |
| **Hubble Observability** | ✅ | ✅ |
| **Metrics Server** | ✅ | ✅ |
| **KubeEdge CloudCore** | ✅ | ✅ |
| **WebSocket/QUIC/HTTPS** | ✅ | ✅ |
| **ArgoCD** | ✅ | ✅ |
| **ROS2 Apps** | ✅ | ✅ |
| **Multi-domain DDS** | ✅ | ✅ |
| **Edge Node Join Script** | ✅ | ✅ |

**Conclusion:** Feature parity is 100% for local KinD deployment.

---

## Use Case Recommendations

### Use Terraform If:

1. **Production AWS/Cloud Deployment**
   ```hcl
   # Easy to scale infrastructure
   resource "aws_eks_cluster" "main" {
     # Multi-zone setup
   }
   ```

2. **Multiple Environments**
   ```
   environments/
   ├── development/
   ├── staging/
   └── production/
   ```

3. **State Tracking Required**
   - Need to know what's deployed
   - Team managing shared infrastructure
   - Need `terraform plan` for reviews

4. **Complex Infrastructure**
   - Networking, VPCs, security groups
   - Databases, load balancers
   - DNS, certificates

5. **IaC Best Practices**
   - Professional infrastructure team
   - Audit requirements
   - Change tracking needed

6. **Team Preference**
   - Team already knows Terraform
   - Organization standard

### Use Ansible If:

1. **Local Development**
   ```bash
   # Get cluster running in seconds
   make kind-deploy
   ```

2. **Quick Prototyping**
   - Iterate quickly
   - No state file overhead
   - Immediate feedback

3. **Ops Team Familiar with YAML**
   - DevOps/SRE teams
   - Configuration management background
   - Playbooks make sense

4. **Simple, Single Environment**
   ```bash
   # Just local KinD cluster
   # No multi-cloud complexity
   ```

5. **Rapid Changes**
   - Run playbook multiple times safely
   - No state conflicts
   - Easy debugging

6. **Learning/Demo**
   - Easier for teams to understand
   - Lower barrier to entry
   - Simpler troubleshooting

---

## Side-by-Side Examples

### Creating the Cluster

**Terraform:**
```hcl
module "kind_cluster" {
  source = "../../../modules/kubernetes-cluster-kind"

  cluster_name        = var.cluster_name
  node_image          = var.node_image
  control_plane_count = var.control_plane_count
  worker_node_count   = var.worker_node_count
}
```

**Ansible:**
```yaml
- name: Create kind cluster
  shell: kind create cluster --config /tmp/kind-config.yaml
  register: cluster_creation
```

**Winner:** Tie (both clear)

---

### Deploying KubeEdge

**Terraform:**
```hcl
resource "kubernetes_deployment" "cloudcore" {
  metadata {
    name = "cloudcore"
  }
  # ... full spec
}
```

**Ansible:**
```yaml
- name: Create CloudCore Deployment
  kubernetes.core.k8s:
    definition: <yaml_definition>
    state: present
```

**Winner:** Ansible (more concise for Kubernetes)

---

### Checking Status

**Terraform:**
```bash
terraform plan      # Show what changed
terraform apply     # Apply changes
terraform state     # View state
```

**Ansible:**
```bash
ansible-playbook playbooks/site.yml -vvv    # Run with verbose
kubectl get pods                              # Check results
```

**Winner:** Terraform (plan is powerful)

---

## Migration Paths

### From Terraform to Ansible

If you started with Terraform but want to switch:

```bash
# Export what you learned
# Cluster: robotics-dev, 3 control planes, 6 workers, Cilium CNI
# Apps: KubeEdge, ArgoCD, ROS2

# Delete infrastructure
make destroy

# Deploy with Ansible
make kind-deploy

# Same result, different tool
```

### From Ansible to Terraform

If you started with Ansible and want enterprise-grade:

```bash
# Terraform has modules already built
# Your playbook taught you what you need

# Switch approaches
cd infra/environments/development/kind-local
terraform init
terraform apply

# Same result, with state management
```

---

## Operational Considerations

### State Management

**Terraform:**
```
terraform.state        # Critical file - must backup!
terraform.state.backup # Automatic backup
```

**Ansible:**
```
No state file
Each run is idempotent
```

**Recommendation:** Terraform needs git workflow or S3 backend for state.

### Team Collaboration

**Terraform:**
- Need to manage state locks
- State conflicts possible
- State must be shared (remote backend)
- Pull request reviews of plans

**Ansible:**
- Run playbooks independently
- No state locks
- Idempotent (safe for multiple runs)
- Easier for ad-hoc changes

### Debugging

**Terraform:**
```bash
terraform plan      # See what will happen
terraform apply -var-file=debug.tfvars
TF_LOG=DEBUG terraform apply
```

**Ansible:**
```bash
ansible-playbook playbooks/site.yml -vvv
ansible-playbook playbooks/site.yml --step
```

---

## Long-Term Maintenance

### Kubernetes Updates

**Scenario:** Upgrade Kubernetes from 1.27 to 1.29

**Terraform Approach:**
```hcl
variable "k8s_version" {
  default = "v1.29.2"  # Change this
}
terraform plan  # See impact
terraform apply # Apply changes
```

**Ansible Approach:**
```yaml
k8s_version: "v1.29.2"  # Change this
ansible-playbook playbooks/provision-kind-cluster.yml
```

**Winner:** Terraform (plan shows exactly what changes)

---

## Cost Considerations

Both approaches cost the same for infrastructure. Differences are in operations:

**Terraform:**
- Better for team with IaC expertise (lower learning curve)
- Requires state management (S3, Terraform Cloud)
- Slightly more setup time

**Ansible:**
- Better for ops-heavy teams (no licensing)
- No state management needed
- Faster iteration

---

## Hybrid Approach

You can use **both** for different purposes:

```
Development: Ansible (fast iteration)
├── make kind-deploy  (local experimentation)

Production: Terraform (state, audit trail)
├── terraform apply   (AWS, GCP, Azure)
```

This is actually supported! Deploy locally with Ansible, production with Terraform.

---

## Final Recommendation

### For Most Teams:

**Start with Ansible for:**
1. Local development
2. Quick prototyping
3. Understanding the platform

**Move to Terraform for:**
1. Multi-environment setup
2. Production infrastructure
3. Enterprise requirements

**Both are production-ready** for their intended use cases.

---

## Summary Table

| Aspect | Terraform | Ansible | Winner |
|--------|-----------|---------|--------|
| Setup time | 5 min | 2 min | Ansible |
| Deployment speed | 5-10 min | 5-10 min | Tie |
| Ease of learning | Moderate | Easy | Ansible |
| Production ready | Yes | Yes* | Tie |
| State management | Excellent | Not applicable | Terraform |
| Local dev | Good | Excellent | Ansible |
| Multi-cloud | Excellent | Manual | Terraform |
| Team familiarity | High in cloud teams | High in ops | Context-dependent |

*Ansible is production-ready for configuration, not infrastructure provisioning.

---

## Next Steps

### Choose Terraform If:
→ Go to `QUICKSTART.md`

### Choose Ansible If:
→ Go to `QUICKSTART_ANSIBLE.md`

### Want to Understand Both:
→ See `ARCHITECTURE.md` (same platform, different tools)

---

## Support

- **Terraform:** `QUICKSTART.md`, `ARCHITECTURE.md`, `terraform --help`
- **Ansible:** `QUICKSTART_ANSIBLE.md`, `infra/ansible/README.md`, `ansible-playbook --help`
- **Both:** `KUBEEDGE_GUIDE.md`, `README.md`
