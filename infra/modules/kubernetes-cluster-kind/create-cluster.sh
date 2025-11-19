#!/bin/bash
set -e

CLUSTER_NAME=$1
CONTROL_PLANE_COUNT=$2
WORKER_COUNT=$3
NODE_IMAGE=$4
API_PORT=${5:-6444}

# Create kind config file
CONFIG_FILE=$(mktemp)

cat > "$CONFIG_FILE" <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
networking:
  ipFamily: ipv4
  apiServerPort: 6443
  disableDefaultCNI: true
nodes:
EOF

# Add control plane nodes
for ((i=0; i<CONTROL_PLANE_COUNT; i++)); do
  cat >> "$CONFIG_FILE" <<EOF
- role: control-plane
  image: $NODE_IMAGE
EOF
  # Only first control plane gets port mapping
  if [ $i -eq 0 ]; then
    cat >> "$CONFIG_FILE" <<EOF
  extraPortMappings:
  - containerPort: 6443
    hostPort: $API_PORT
    listenAddress: 127.0.0.1
    protocol: TCP
EOF
  fi
done

# Add worker nodes
for ((i=0; i<WORKER_COUNT; i++)); do
  cat >> "$CONFIG_FILE" <<EOF
- role: worker
  image: $NODE_IMAGE
EOF
done

# Create cluster
kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"

# Clean up
rm -f "$CONFIG_FILE"
