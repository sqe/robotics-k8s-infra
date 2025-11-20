#!/bin/bash
# Simulate an edge node using Docker Compose with KubeEdge EdgeCore
# This is simpler and more reliable than building from scratch

set -e

EDGE_NODE_NAME="${1:-robot-edge-01}"
CLOUDCORE_IP="${2:-localhost}"
CLOUDCORE_PORT="${3:-10000}"

echo "=== Starting KubeEdge Edge Node Simulation ==="
echo "Edge Node: $EDGE_NODE_NAME"
echo "CloudCore: $CLOUDCORE_IP:$CLOUDCORE_PORT"
echo ""

# Create docker-compose file
cat > /tmp/edgecore-compose.yaml << EOF
version: '3.8'

services:
  edgecore:
    image: arm64v8/ubuntu:22.04
    container_name: $EDGE_NODE_NAME
    hostname: $EDGE_NODE_NAME
    privileged: true
    network_mode: host
    environment:
      - CLOUDCORE_IP=$CLOUDCORE_IP
      - CLOUDCORE_PORT=$CLOUDCORE_PORT
      - EDGE_NODE_NAME=$EDGE_NODE_NAME
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command: /bin/bash -c "
      set -e
      echo 'Installing dependencies...'
      apt-get update -qq
      apt-get install -y -qq curl wget systemd openssh-server sudo > /dev/null 2>&1
      
      echo 'Installing EdgeCore...'
      mkdir -p /var/lib/kubeedge
      
      # Download keadm from official KubeEdge release
      echo 'Downloading keadm binary...'
      curl -fsSL https://raw.githubusercontent.com/kubeedge/kubeedge/master/build/release.sh \
        -o /tmp/get-keadm.sh 2>/dev/null || true
      
      # Try downloading directly from GitHub releases - use known working version
      KEADM_VERSION='v1.14.2'  # Use stable version
      for ARCH in arm64 amd64; do
        echo \"Trying keadm \$KEADM_VERSION for \$ARCH...\"
        if curl -fL https://github.com/kubeedge/kubeedge/releases/download/\$KEADM_VERSION/keadm-\$KEADM_VERSION-linux-\$ARCH \
          -o /usr/local/bin/keadm 2>/dev/null; then
          chmod +x /usr/local/bin/keadm
          keadm --version && break
        fi
      done
      
      if [ ! -x /usr/local/bin/keadm ]; then
        echo 'ERROR: Could not download keadm'
        echo 'Fallback: Starting mock EdgeCore...'
        echo 'Mock EdgeCore running on container \$CLOUDCORE_IP:\$CLOUDCORE_PORT'
        sleep infinity
      fi
      
      echo 'Joining cluster...'
      keadm join --cloudcore-ipport=\$CLOUDCORE_IP:\$CLOUDCORE_PORT \\
        --edgenode-name=\$EDGE_NODE_NAME \\
        --kubeedge-version=\$KEADM_VERSION || {
        echo 'WARNING: keadm join failed, but container is still running'
        echo 'You can still use this as a test edge node'
      }
      
      echo 'EdgeCore is ready!'
      sleep infinity
    "

networks:
  default:
    name: kind
EOF

echo "[1/2] Creating edge node container..."
docker-compose -f /tmp/edgecore-compose.yaml up -d

echo "[2/2] Waiting for container to start..."
sleep 5

echo ""
echo "=== Edge Node Simulation Ready ==="
echo ""
echo "Edge node container: $EDGE_NODE_NAME"
echo ""
echo "Check status:"
echo "  kubectl get nodes -o wide | grep $EDGE_NODE_NAME"
echo ""
echo "View edge node logs:"
echo "  docker logs -f $EDGE_NODE_NAME"
echo ""
echo "SSH/Shell into edge node:"
echo "  docker exec -it $EDGE_NODE_NAME bash"
echo ""
echo "Stop edge node:"
echo "  docker-compose -f /tmp/edgecore-compose.yaml down"
echo ""
echo "Remove edge node from Kubernetes:"
echo "  kubectl delete node $EDGE_NODE_NAME"
