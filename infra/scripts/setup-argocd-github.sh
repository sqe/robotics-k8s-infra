#!/bin/bash
set -e

# Script to setup ArgoCD with GitHub repository
# Usage: ./setup-argocd-github.sh <github-repo-url> <github-pat-token> [argocd-namespace]

REPO_URL="${1:-}"
GITHUB_TOKEN="${2:-}"
ARGOCD_NAMESPACE="${3:-argocd}"

if [ -z "$REPO_URL" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Usage: $0 <github-repo-url> <github-pat-token> [argocd-namespace]"
  echo ""
  echo "Example:"
  echo "  $0 https://github.com/sqe/robotics-k8s-infra ghp_xxxxx"
  exit 1
fi

echo "Setting up ArgoCD with GitHub repository..."
echo "Repository: $REPO_URL"
echo "Namespace: $ARGOCD_NAMESPACE"
echo ""

# Create the repository secret
echo "Creating GitHub credentials secret..."
kubectl create secret generic github-repo \
  --from-literal=type=git \
  --from-literal=url="$REPO_URL" \
  --from-literal=password="$GITHUB_TOKEN" \
  --from-literal=username=git \
  -n "$ARGOCD_NAMESPACE" \
  --dry-run=client -o yaml | \
  kubectl label -f - argocd.argoproj.io/secret-type=repository -o yaml | \
  kubectl apply -f -

echo "✓ GitHub credentials secret created"
echo ""

# Wait for ArgoCD server to be ready
echo "Waiting for ArgoCD server..."
kubectl rollout status deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=5m

echo "✓ ArgoCD server is ready"
echo ""

# Get ArgoCD CLI login credentials
echo "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo "✓ Password retrieved"
echo ""

# Forward to ArgoCD server
echo "Setting up port forward to ArgoCD server..."
echo "Run this in another terminal:"
echo "  kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
echo ""
echo "Then access ArgoCD at: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""

# Create example ArgoCD application that syncs from the repo
echo "Would you like to create an example ArgoCD Application?"
echo "This will deploy all manifests from the 'apps/' directory in your repo."
echo ""
read -p "Create example application? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  cat << EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: robotics-apps
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
  echo "✓ Example application created: robotics-apps"
  echo ""
  echo "Check status:"
  echo "  argocd app list"
  echo "  argocd app get robotics-apps"
else
  echo "Skipped creating example application"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Port forward: kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
echo "  2. Login at https://localhost:8080 with admin/$ARGOCD_PASSWORD"
echo "  3. Create applications in ArgoCD UI or via CLI"
