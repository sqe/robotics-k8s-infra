#!/bin/bash
set -e

CLUSTER_NAME=$1

echo "Installing Cilium and Hubble for cluster: $CLUSTER_NAME"

# Wait for cluster to be ready
kubectl cluster-info --context "kind-$CLUSTER_NAME" || exit 1

# Check if cilium-cli is installed
if ! command -v cilium &> /dev/null; then
  echo "Installing cilium-cli..."
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  CLI_ARCH=amd64
  if [ "$(uname -m)" = "arm64" ]; then
    CLI_ARCH=arm64
  fi
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz
  sudo tar xzvfC cilium-darwin-${CLI_ARCH}.tar.gz /usr/local/bin
  rm cilium-darwin-${CLI_ARCH}.tar.gz
fi

# Install Cilium with Hubble enabled
echo "Installing Cilium..."
cilium install \
  --context "kind-$CLUSTER_NAME" \
  --helm-set hubble.relay.enabled=true \
  --helm-set hubble.ui.enabled=true \
  --helm-set l7Proxy=true \
  --helm-set operator.prometheus.enabled=true \
  --helm-set prometheus.enabled=true

# Wait for Cilium to be ready
echo "Waiting for Cilium to be ready..."
cilium status --context "kind-$CLUSTER_NAME" --wait

# Verify installation
echo "Verifying Cilium installation..."
cilium connectivity test --context "kind-$CLUSTER_NAME"

echo "Hubble and Cilium installed successfully!"
echo ""
echo "To access Hubble UI, run:"
echo "  cilium hubble ui --context kind-$CLUSTER_NAME"
echo ""
echo "To view network flows:"
echo "  cilium hubble observe --context kind-$CLUSTER_NAME"
