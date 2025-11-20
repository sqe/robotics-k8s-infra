# Getting Started - Choose Your Deployment Method

Welcome! This platform can be deployed two ways. Choose the one that fits your team best.

## 🚀 Quick Choose-Your-Own-Adventure

### ❓ What's your situation?

**"I just want to try it out locally"**
→ Use **Ansible**  
→ Run: `make kind-deploy`  
→ Read: `QUICKSTART_ANSIBLE.md`

**"We use Terraform for everything"**
→ Use **Terraform**  
→ Run: `cd infra/environments/development/kind-local && terraform apply`  
→ Read: `QUICKSTART.md`

**"I'm not sure"**
→ Read: `TERRAFORM_VS_ANSIBLE.md`  
→ Then choose based on comparison

**"I need a full overview"**
→ Read: `DEPLOYMENT_OPTIONS.md`  
→ Covers both options completely

---

## 📋 Documentation Map

```
START HERE
    ↓
Choose your method
    ↓
    ├─→ Ansible Path
    │   ├─→ QUICKSTART_ANSIBLE.md         (5 min read)
    │   ├─→ infra/ansible/README.md       (10 min read)
    │   └─→ make kind-deploy              (run)
    │
    └─→ Terraform Path
        ├─→ QUICKSTART.md                 (5 min read)
        ├─→ ARCHITECTURE.md               (10 min read)
        └─→ terraform apply               (run)

BOTH PATHS
    ↓
    ├─→ Verify: kubectl get pods -A
    ├─→ Access: ArgoCD UI
    ├─→ Monitor: kubectl logs -f
    └─→ Explore: KUBEEDGE_GUIDE.md
```

---

## 🎯 Side-by-Side Start

### Option A: Ansible (Recommended for Local Dev)

**Install:**
```bash
pip install ansible
ansible-galaxy collection install kubernetes.core
```

**Deploy:**
```bash
make kind-deploy
```

**Time:** ~10 minutes  
**State file:** None (idempotent)  
**Best for:** Local development, quick iteration

**Learn more:** `QUICKSTART_ANSIBLE.md`

---

### Option B: Terraform (Recommended for Production)

**Install:**
```bash
brew install terraform  # or download from terraform.io
```

**Deploy:**
```bash
cd infra/environments/development/kind-local
terraform init
terraform apply
```

**Time:** ~10 minutes  
**State file:** terraform.state (tracked)  
**Best for:** Production, multi-cloud, enterprise

**Learn more:** `QUICKSTART.md`

---

## ✅ What You'll Get (Either Way)

After deployment, you'll have:

```
✓ Kubernetes Cluster (KinD)
  - 3 control plane nodes
  - 6 worker nodes
  - Cilium CNI + Hubble monitoring

✓ KubeEdge CloudCore
  - WebSocket, QUIC, HTTPS tunnels
  - MQTT message bus
  - Edge node management

✓ ArgoCD
  - GitOps workflow
  - GitHub integration ready
  - Automated deployments

✓ ROS2 Applications
  - Talker/Listener examples
  - Multi-domain DDS support
  - FastDDS discovery server
```

---

## 🏃 Quick Deploy

### Super Fast: One-Line Deploy

**Using Ansible:**
```bash
make kind-deploy
```

**Using Terraform:**
```bash
cd infra/environments/development/kind-local && terraform init && terraform apply -auto-approve
```

Both complete in ~10 minutes.

---

## 📊 Quick Comparison

| | Ansible | Terraform |
|---|---------|-----------|
| **Setup time** | 2 min | 5 min |
| **Deploy time** | 8-10 min | 8-10 min |
| **State file** | No | Yes |
| **Plan preview** | No | Yes |
| **Ease** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Learning** | YAML | HCL |
| **Local dev** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Production** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🔍 Verify Deployment

After running either command, verify with:

```bash
# Check cluster
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -n kubeedge

# View ROS2 logs
kubectl logs -f deployment/ros2-talker-cloud
```

**Expected:** All pods should be Running

---

## 🎓 Learning Path

### 5-Minute Quick Start
1. Run one deploy command
2. Run `kubectl get pods -A`
3. Done!

### 30-Minute Exploration
1. Deploy the platform
2. Read the quick start guide for your choice
3. Access ArgoCD UI
4. View logs

### 2-Hour Deep Dive
1. Deploy with chosen method
2. Read `ARCHITECTURE.md`
3. Read `KUBEEDGE_GUIDE.md`
4. Explore application code
5. Try registering edge nodes

### Full Understanding
1. Deploy both ways (different clusters)
2. Read both quick starts
3. Read `TERRAFORM_VS_ANSIBLE.md`
4. Read `DEPLOYMENT_OPTIONS.md`
5. Explore all documentation

---

## 🛠️ Common First Steps

### Deploy
```bash
make kind-deploy          # Ansible
# OR
terraform apply          # Terraform
```

### Access ArgoCD UI
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
# Open: https://localhost:8080
# Username: admin
# Password: argocd
```

### Watch ROS2 Communication
```bash
kubectl logs -f deployment/ros2-talker-cloud
# See: Publishing Hello World messages
```

### View Edge Node Join Script
```bash
cat /tmp/join-edge-node.sh
# Use on real edge device to register
```

---

## 📚 Full Documentation Index

### Getting Started
- **QUICKSTART.md** - Terraform quick start
- **QUICKSTART_ANSIBLE.md** - Ansible quick start
- **This file** - Navigation guide

### Comparison & Decision
- **TERRAFORM_VS_ANSIBLE.md** - Detailed comparison
- **DEPLOYMENT_OPTIONS.md** - High-level overview
- **ANSIBLE_UPDATES.md** - What's new in Ansible

### Technical Deep Dives
- **ARCHITECTURE.md** - System design
- **KUBEEDGE_GUIDE.md** - Edge computing details
- **IMPLEMENTATION_SUMMARY.md** - What was built
- **ROBOTICS_DEPLOYMENT.md** - Robotics specifics

### Ansible-Specific
- **infra/ansible/README.md** - Comprehensive guide
- **infra/ansible/playbooks/** - All playbooks

### Main Documentation
- **README.md** - Overview
- **README_ROBOTICS.md** - Robotics guide

---

## ❓ FAQ

**Q: Can I use both Terraform and Ansible?**  
A: Yes! They deploy identical platforms. Use Terraform for prod, Ansible for local dev.

**Q: Do I need Docker?**  
A: Yes, both use KinD which requires Docker.

**Q: Can I use this for real robots?**  
A: Yes! Register edge devices with the generated join script.

**Q: What if deployment fails?**  
A: Check the relevant quick start guide or playbook README for troubleshooting.

**Q: Can I customize it?**  
A: Yes! Variables are documented in each quick start. Modify and redeploy.

---

## 🚦 Next Steps

### Choose Now:

1. **For Ansible (Easier, Local Dev):**
   - Click → `QUICKSTART_ANSIBLE.md`
   - Run → `make kind-deploy`
   - Read → `infra/ansible/README.md`

2. **For Terraform (Production-Grade):**
   - Click → `QUICKSTART.md`
   - Run → `terraform apply`
   - Read → `ARCHITECTURE.md`

3. **Not Sure Yet:**
   - Click → `TERRAFORM_VS_ANSIBLE.md`
   - Decide → Based on your needs
   - Then → Follow steps 1 or 2

---

## 💡 Tips for Success

✅ **Do:**
- Choose one method first
- Follow the quick start for that method
- Verify all pods are running
- Read the comprehensive guides for deep learning

❌ **Don't:**
- Switch methods mid-deployment
- Try both at the same time on localhost (conflicts)
- Skip the verification step
- Ignore the relevant documentation

---

## 🆘 Need Help?

1. **Basic troubleshooting** → Check quick start guide
2. **Ansible issues** → See `infra/ansible/README.md`
3. **Terraform issues** → Check `QUICKSTART.md`
4. **Architecture questions** → Read `ARCHITECTURE.md`
5. **KubeEdge specifics** → See `KUBEEDGE_GUIDE.md`

---

## 🎉 Ready?

### Option A: Ansible (Recommended for now)
```bash
make kind-deploy
```
→ Then read `QUICKSTART_ANSIBLE.md`

### Option B: Terraform (For production)
```bash
cd infra/environments/development/kind-local
terraform init && terraform apply
```
→ Then read `QUICKSTART.md`

Either way, you'll have a production-grade robotics platform in 10 minutes! 🚀

---

**Make your choice above and get started!**

Questions? Check the documentation index above for the right guide.
