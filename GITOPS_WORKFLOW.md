# GitOps Workflow with Terraform + ArgoCD

This project separates infrastructure and workloads:

- **Terraform** (infra/) - Provisions Kubernetes clusters, Cilium CNI, ArgoCD, monitoring
- **ArgoCD** (apps/) - Manages applications and workloads via GitOps

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Your Git Repository                                      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  infra/                    apps/                          │
│  ├─ modules/              ├─ base/                        │
│  │  ├─ kind              │  ├─ ros2-deployment/          │
│  │  ├─ argocd            │  └─ ...                        │
│  │  └─ cilium            │                                │
│  ├─ environments/        └─ overlays/                     │
│  │  └─ kind-local/          ├─ development/              │
│  └─ ...                      ├─ staging/                  │
│                              └─ production/              │
└─────────────────────────────────────────────────────────┘
           │
           │ terraform apply
           ▼
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                       │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐  ┌──────────────────┐             │
│  │ Cilium CNI       │  │ Prometheus       │             │
│  │ + Hubble         │  │ Monitoring       │             │
│  └──────────────────┘  └──────────────────┘             │
│                                                           │
│  ┌──────────────────────────────────────────┐           │
│  │ ArgoCD                                    │           │
│  │ ┌────────────────────────────────────┐  │           │
│  │ │ App Controller                      │  │           │
│  │ │ (git change → kubectl apply)       │  │           │
│  │ └────────────────────────────────────┘  │           │
│  └──────────────────────────────────────────┘           │
│         │                                                │
│         └────► git pull ─────┐                          │
│                              │                          │
│  ┌──────────────────────────────────────────┐           │
│  │ Your Workloads                           │           │
│  │ ├─ ROS 2 Nodes                           │           │
│  │ ├─ Sensors                               │           │
│  │ ├─ ML Pipelines                          │           │
│  │ └─ ...                                   │           │
│  └──────────────────────────────────────────┘           │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Setup

### 1. Deploy Infrastructure

```bash
cd infra/environments/development/kind-local
terraform init
terraform apply

# Get cluster info
terraform output kubeconfig_path
terraform output argocd_access_command
```

### 2. Access ArgoCD UI

```bash
# From terraform output, run the port-forward command
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Access UI at https://localhost:8080
```

### 3. Configure Git Repository

ArgoCD needs access to your git repo. Two options:

#### Option A: HTTPS with Personal Access Token

```bash
argocd repo add https://github.com/YOUR_ORG/tf.git \
  --username github-user \
  --password ghp_YourPersonalAccessToken
```

#### Option B: SSH Key

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/argocd-deploy-key -N ""

# Add public key to GitHub repo settings (Deploy Keys)
cat ~/.ssh/argocd-deploy-key.pub

# Register with ArgoCD
argocd repo add git@github.com:YOUR_ORG/tf.git \
  --ssh-private-key-path ~/.ssh/argocd-deploy-key
```

### 4. Deploy Applications

```bash
# Update the git repo URL in apps/applications/base-apps.yaml
cd apps/applications
sed -i 's|https://github.com/YOUR_ORG/tf.git|YOUR_ACTUAL_REPO|g' base-apps.yaml

# Apply the Application manifests
kubectl apply -f base-apps.yaml

# Monitor
argocd app list
argocd app watch robotics-platform --refresh 5s
```

## Workflow Examples

### Example 1: Deploy ROS 2 Node

```bash
# Create overlay for your environment
mkdir -p apps/overlays/development/my-ros2-node
cp -r apps/overlays/development/robotics-platform/* apps/overlays/development/my-ros2-node/

# Edit deployment-patch.yaml
cat > apps/overlays/development/my-ros2-node/deployment-patch.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-node
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: ros2-node
        image: my-org/my-ros2-node:latest
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
EOF

# Create ArgoCD Application
cat > apps/applications/my-ros2-node-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-ros2-node
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/tf.git
    targetRevision: main
    path: apps/overlays/development/my-ros2-node
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Commit and push
git add apps/
git commit -m "Add my-ros2-node deployment"
git push

# Apply in ArgoCD
kubectl apply -f apps/applications/my-ros2-node-app.yaml

# Monitor deployment
argocd app watch my-ros2-node
```

### Example 2: Update Image Version

The entire point of GitOps - update git, ArgoCD auto-deploys:

```bash
# Edit your kustomization to use a new image
cat > apps/overlays/development/my-ros2-node/deployment-patch.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-node
spec:
  template:
    spec:
      containers:
      - name: ros2-node
        image: my-org/my-ros2-node:v2.0  # Updated version
EOF

# Commit
git add apps/overlays/development/my-ros2-node/deployment-patch.yaml
git commit -m "Bump ROS 2 node to v2.0"
git push

# ArgoCD detects change automatically (within 3 mins)
# Or force sync immediately:
argocd app sync my-ros2-node
```

### Example 3: Scale Deployment

```bash
# Edit replica count in Kustomization
cat > apps/overlays/development/my-ros2-node/deployment-patch.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-node
spec:
  replicas: 5  # Scale to 5
EOF

git add apps/overlays/development/my-ros2-node/deployment-patch.yaml
git commit -m "Scale ROS 2 nodes to 5 replicas"
git push

# Auto-deployed via ArgoCD
```

## Advanced: ApplicationSet for Multiple Environments

Deploy to dev/staging/prod from a single definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: robotics-multienv
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: development
        namespace: default
        domain: dev.example.com
      - cluster: staging
        namespace: staging
        domain: staging.example.com
      - cluster: production
        namespace: production
        domain: prod.example.com
  
  template:
    metadata:
      name: 'robotics-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_ORG/tf.git
        targetRevision: main
        path: 'apps/overlays/{{cluster}}/robotics-platform'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Best Practices

### Do's

✅ **Everything in Git** - All infrastructure and workloads in version control
✅ **Kustomize Overlays** - Keep base manifests reusable, use overlays per environment
✅ **ArgoCD Auto-Sync** - Enable automated sync for desired state management
✅ **Resource Quotas** - Define limits for each namespace
✅ **Network Policies** - Use Cilium policies to restrict ROS traffic
✅ **GitOps Secrets** - Use sealed-secrets or external-secrets for sensitive data
✅ **Pull Requests** - Review changes before auto-deploying

### Don'ts

❌ Manual kubectl apply (defeats purpose of GitOps)
❌ Hardcoded environment values in base manifests
❌ Plain text secrets in git
❌ Disabling auto-sync in production
❌ Using `latest` image tags

## Troubleshooting

### Application stuck "OutOfSync"

```bash
# Check what's different
argocd app diff robotics-platform

# Force sync
argocd app sync robotics-platform --force

# Check detailed status
argocd app get robotics-platform
```

### ArgoCD can't access git repo

```bash
# List configured repos
argocd repo list

# Test connection
argocd repo list --url https://github.com/YOUR_ORG/tf.git

# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

### Secrets management

```bash
# Install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Seal a secret
echo -n mypassword | kubectl create secret generic my-secret --dry-run=client --from-file=- | kubeseal -o yaml > sealed-secret.yaml

# Add to git
git add sealed-secret.yaml
```

## Monitoring

### Check Hubble flows for your apps

```bash
# Watch traffic to ROS 2 pods
cilium hubble observe --pod default/ros2-node --follow

# Check multicast discovery traffic
cilium hubble observe --verdict=INGRESS --type=Trace | grep -i "239.255"
```

### ArgoCD Metrics

```bash
# Port-forward Prometheus (if enabled)
kubectl port-forward svc/prometheus -n monitoring 9090:9090

# View ArgoCD application metrics
# Access http://localhost:9090 and query:
# argocd_app_sync_duration_seconds
# argocd_app_reconcile_count
```
