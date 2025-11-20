#!/bin/bash
# Simulate an edge node joining KubeEdge cluster
# This creates a Docker container that acts as an edge node

set -e

EDGE_NODE_NAME="${1:-robot-edge-01}"
CLOUDCORE_IP="${2:-localhost}"
CLOUDCORE_PORT="${3:-10000}"
KUBEEDGE_VERSION="1.15.0"
DOCKER_IMAGE="arm64v8/ubuntu:22.04"

echo "=== Starting Edge Node Simulation ==="
echo "Edge Node: $EDGE_NODE_NAME"
echo "CloudCore: $CLOUDCORE_IP:$CLOUDCORE_PORT"
echo ""

# 1. Create edge node container
echo "[1/3] Creating edge node container..."
docker run -d \
  --name "$EDGE_NODE_NAME" \
  --hostname "$EDGE_NODE_NAME" \
  --network host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v /proc:/proc:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "$DOCKER_IMAGE" \
  sleep infinity

# 2. Install keadm and dependencies
echo "[2/3] Installing keadm v${KUBEEDGE_VERSION} in container..."
docker exec "$EDGE_NODE_NAME" bash -c "
set -e
echo 'Installing dependencies...'
apt-get update > /dev/null 2>&1
apt-get install -y curl wget net-tools iproute2 iputils-ping docker.io > /dev/null 2>&1

echo 'Downloading keadm...'
ARCH=\$(uname -m)
if [ \"\$ARCH\" = \"aarch64\" ]; then
  ARCH=\"arm64\"
fi

curl -L https://github.com/kubeedge/kubeedge/releases/download/v${KUBEEDGE_VERSION}/keadm-v${KUBEEDGE_VERSION}-linux-\$ARCH \
  -o /usr/local/bin/keadm 2>/dev/null && chmod +x /usr/local/bin/keadm || {
  echo 'Failed to download keadm, using fallback...'
  curl -L https://github.com/kubeedge/kubeedge/releases/download/v${KUBEEDGE_VERSION}/keadm-v${KUBEEDGE_VERSION}-linux-amd64 \
    -o /usr/local/bin/keadm 2>/dev/null && chmod +x /usr/local/bin/keadm
}

keadm --version
"

# 3. Join edge node to cluster
echo "[3/3] Joining edge node to CloudCore..."
docker exec "$EDGE_NODE_NAME" bash -c "
echo 'Joining cluster...'
keadm join --cloudcore-ipport=$CLOUDCORE_IP:$CLOUDCORE_PORT \
  --edgenode-name=$EDGE_NODE_NAME \
  --kubeedge-version=v${KUBEEDGE_VERSION} \
  --skip-pull-images=true \
  2>&1 || true

echo 'Waiting for EdgeCore to start...'
sleep 5

# Check EdgeCore status
if systemctl is-active --quiet edgecore; then
  echo '✅ EdgeCore started successfully'
  systemctl status edgecore --no-pager || true
else
  echo '⚠️  EdgeCore may not be running, checking logs...'
  journalctl -u edgecore -n 20 --no-pager || true
fi
"

echo ""
echo "=== Edge Node Simulation Ready ==="
echo ""
echo "Edge node container: $EDGE_NODE_NAME"
echo ""
echo "Check edge node status:"
echo "  kubectl get nodes -o wide | grep $EDGE_NODE_NAME"
echo ""
echo "View edge node logs:"
echo "  docker exec $EDGE_NODE_NAME journalctl -u edgecore -f"
echo ""
echo "SSH into edge node:"
echo "  docker exec -it $EDGE_NODE_NAME bash"
echo ""
echo "Stop edge node:"
echo "  docker stop $EDGE_NODE_NAME"
echo ""
echo "Remove edge node:"
echo "  docker rm -f $EDGE_NODE_NAME"
echo "  keadm reset --server=$CLOUDCORE_IP:$CLOUDCORE_PORT (from edge node)"
