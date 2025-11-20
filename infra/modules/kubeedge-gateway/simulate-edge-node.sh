#!/bin/bash
# Simulate a robot/edge node with ROS2 talker running
# This creates Kubernetes pods that act as an edge device

set -e

EDGE_NODE_NAME="${1:-robot-edge-01}"
WORKER_NODE="${2:-robotics-dev-worker}"
ROS_DOMAIN_ID="${3:-42}"

echo "=== Starting Edge Node Simulation ==="
echo "Edge Node: $EDGE_NODE_NAME"
echo "Worker Node: $WORKER_NODE"
echo "ROS Domain ID: $ROS_DOMAIN_ID"
echo ""

# 0. Clean up if pod already exists
echo "[0/3] Cleaning up existing resources..."
kubectl delete pod "$EDGE_NODE_NAME" --force --grace-period=0 2>/dev/null || true
kubectl delete deployment ros2-talker-edge 2>/dev/null || true
sleep 2

# 1. Create edge node simulator pod
echo "[1/3] Creating edge node simulator pod..."
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: $EDGE_NODE_NAME
  labels:
    app: edge-simulator
    node-role.kubernetes.io/edge: "true"
    ros-domain: "$ROS_DOMAIN_ID"
spec:
  nodeSelector:
    kubernetes.io/hostname: $WORKER_NODE
  containers:
  - name: edgecore-simulator
    image: arm64v8/ros:humble
    imagePullPolicy: IfNotPresent
    command: ["/bin/bash"]
    args: ["-c", "sleep infinity"]
    env:
    - name: ROS_DOMAIN_ID
      value: "$ROS_DOMAIN_ID"
    - name: ROS_LOCALHOST_ONLY
      value: "0"
    - name: RCUTILS_LOGGING_USE_STDOUT
      value: "1"
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
EOF

# 2. Create ROS2 talker deployment on edge node
echo "[2/3] Creating ROS2 talker on edge node..."
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-talker-edge
  labels:
    app: ros2-talker-edge
    edge-node: $EDGE_NODE_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ros2-talker-edge
  template:
    metadata:
      labels:
        app: ros2-talker-edge
        edge-node: $EDGE_NODE_NAME
        ros-domain: "$ROS_DOMAIN_ID"
    spec:
      nodeSelector:
        kubernetes.io/hostname: $WORKER_NODE
      containers:
      - name: talker
        image: arm64v8/ros:humble
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args: 
        - -c
        - |
          set -e
          echo "Installing ROS2 packages..."
          apt-get update > /dev/null 2>&1
          apt-get install -y ros-humble-demo-nodes-cpp > /dev/null 2>&1
          
          echo "Starting ROS2 talker..."
          source /opt/ros/humble/setup.bash
          exec ros2 run demo_nodes_cpp talker
        env:
        - name: ROS_DOMAIN_ID
          value: "$ROS_DOMAIN_ID"
        - name: ROS_LOCALHOST_ONLY
          value: "0"
        - name: RCUTILS_LOGGING_USE_STDOUT
          value: "1"
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - "ps aux | grep ros2 | grep -v grep"
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
EOF

# 3. Wait for pods to start
echo "[3/3] Waiting for edge node to be ready..."
kubectl wait --for=condition=ready pod/$EDGE_NODE_NAME --timeout=60s 2>/dev/null || {
  echo "⚠️  Pod not immediately ready, checking status..."
  kubectl describe pod/$EDGE_NODE_NAME
}

echo ""
echo "=== Edge Node Simulation Ready ==="
echo ""
echo "Edge Node Name: $EDGE_NODE_NAME"
echo "Worker Node: $WORKER_NODE"
echo "ROS Domain ID: $ROS_DOMAIN_ID"
echo ""
echo "Verify deployment:"
echo "  kubectl get pods -o wide | grep $EDGE_NODE_NAME"
echo "  kubectl get pods -o wide | grep ros2-talker-edge"
echo ""
echo "View edge node simulator logs:"
echo "  kubectl logs -f $EDGE_NODE_NAME"
echo ""
echo "View ROS2 talker logs:"
echo "  kubectl logs -f deployment/ros2-talker-edge -c talker"
echo ""
echo "Check ROS2 topics on edge:"
echo "  kubectl exec -it $EDGE_NODE_NAME -- bash -c 'source /opt/ros/humble/setup.bash && ros2 topic list'"
echo ""
echo "Shell into edge node:"
echo "  kubectl exec -it $EDGE_NODE_NAME -- bash"
echo ""
echo "Shell into talker pod:"
echo "  kubectl exec -it deployment/ros2-talker-edge -- bash"
echo ""
echo "Monitor edge node CPU/memory:"
echo "  kubectl top pod $EDGE_NODE_NAME"
echo ""
echo "Delete edge node:"
echo "  kubectl delete pod $EDGE_NODE_NAME"
echo "  kubectl delete deployment ros2-talker-edge"
