# ArgoCD Applications

This directory contains Kubernetes manifests and ArgoCD Application definitions for workload deployment.

## Structure

```
apps/
├── base/                    # Base manifests (reusable)
│   ├── ros2-deployment/
│   ├── monitoring/
│   └── robotics-platform/
├── overlays/                # Kustomize overlays for different environments
│   ├── development/
│   ├── staging/
│   └── production/
└── applications/            # ArgoCD Application CRDs
    ├── base-apps.yaml      # Foundational applications
    └── workload-apps.yaml  # ROS 2 and robotics workloads
```

## Deployment Flow

1. **Terraform** provisions infrastructure (Kubernetes cluster + ArgoCD)
2. **ArgoCD** syncs applications from this directory
3. Applications auto-update when manifests change in git

## Quick Start

### Deploy Applications

```bash
# Register the app repo (example using GitHub)
argocd repo add https://github.com/your-org/tf.git --username <username> --password <token>

# Create ArgoCD Application to sync apps
kubectl apply -f apps/applications/base-apps.yaml

# Monitor sync
argocd app list
argocd app watch robotics-platform --refresh 5s
```

### Manual Sync

```bash
# Sync specific application
argocd app sync robotics-platform

# Full sync with prune
argocd app sync robotics-platform --prune
```

### Debugging

```bash
# Check application status
argocd app get robotics-platform

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Check git sync errors
kubectl describe application robotics-platform -n argocd
```

## Adding New Applications

### 1. Create base manifests

```bash
mkdir -p apps/base/my-app
cat > apps/base/my-app/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-org/my-app:1.0
EOF

cat > apps/base/my-app/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 8080
    targetPort: 8080
EOF

cat > apps/base/my-app/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF
```

### 2. Create ArgoCD Application

```bash
cat > apps/applications/my-app-application.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/tf.git
    targetRevision: main
    path: apps/overlays/development/my-app
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
```

### 3. Create environment overlay

```bash
mkdir -p apps/overlays/development/my-app
cat > apps/overlays/development/my-app/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../../base/my-app
patchesStrategicMerge:
- deployment-patch.yaml
EOF

cat > apps/overlays/development/my-app/deployment-patch.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: my-app
        resources:
          limits:
            memory: "256Mi"
            cpu: "250m"
EOF
```

### 4. Commit and sync

```bash
git add apps/
git commit -m "Add my-app application"
git push

# Sync in ArgoCD
argocd app create -f apps/applications/my-app-application.yaml
```

## ROS 2 Deployment Example

See `apps/base/ros2-deployment/` for a complete ROS 2 example with:
- Multi-node DDS configuration
- Custom network policies for ROS topics
- Persistent volumes for bag files
- Cilium network policies

## Best Practices

1. **Use Overlays** - Keep base manifests environment-agnostic
2. **Version Everything** - Use image tags, not `latest`
3. **Resource Limits** - Always set CPU/memory limits
4. **Network Policies** - Define explicit network policies for ROS traffic
5. **Monitoring** - Deploy Prometheus scrape configs with workloads
6. **Health Checks** - Include readiness/liveness probes
7. **Rollback Strategy** - Use ArgoCD's built-in rollback on sync failures

## Troubleshooting

### Application stuck in syncing

```bash
# Check resource status
kubectl get all -n default
kubectl describe pod <pod-name>

# Force terminate
argocd app terminate-op my-app
argocd app sync my-app --force
```

### Git authentication errors

```bash
# Check git credentials
argocd repo list

# Update repo credentials
argocd repo rm https://github.com/your-org/tf.git
argocd repo add https://github.com/your-org/tf.git --ssh-private-key-path ~/.ssh/id_rsa
```

### Out of sync with git

```bash
# Check diff
argocd app diff robotics-platform

# Manual sync
argocd app sync robotics-platform
```
