# KubeEdge Gateway Deployment Guide

Complete guide for deploying KubeEdge CloudCore and managing edge nodes in your robotics cluster.

## Overview

KubeEdge extends Kubernetes to the edge, enabling seamless cloud-edge computing for IoT devices, robots, and edge servers. This guide covers:

- **CloudCore**: Cloud-side management component
- **EdgeCore**: Edge-side daemon (auto-deployed on edge nodes)
- **EdgeMesh**: Networking overlay for service discovery
- **ROS 2 Integration**: Running robotics applications on edge nodes

## Architecture

```
┌──────────────────────────────────────┐
│    Kubernetes Control Plane          │
│    (Cloud - kind-local or AWS)       │
│                                      │
│  ┌────────────────────────────────┐  │
│  │   KubeEdge CloudCore           │  │
│  │  ├─ CloudHub (WebSocket)       │  │
│  │  │  ├─ Port 10000              │  │
│  │  │  └─ Cloud-to-Edge tunnel    │  │
│  │  │                             │  │
│  │  ├─ QUIC (Fast lane)           │  │
│  │  │  ├─ Port 10001              │  │
│  │  │  └─ Optimized tunnel        │  │
│  │  │                             │  │
│  │  ├─ HTTPS (Secure)             │  │
│  │  │  └─ Port 10002              │  │
│  │  │                             │  │
│  │  └─ EventBus (MQTT)            │  │
│  │     ├─ Port 1883               │  │
│  │     └─ Message broker          │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
           ▲   ▲   ▲
       TLS WebSocket QUIC
           │   │   │
    ┌──────┴───┴───┴──────┐
    │  Network (Internet) │
    └──────┬───┬───┬──────┘
           │   │   │
    ┌──────▼───▼───▼───────┐
    │  Edge Nodes (Robots) │
    │  ┌─────────────────┐ │
    │  │  EdgeCore       │ │
    │  │ ├─ Sync state   │ │
    │  │ ├─ Run pods     │ │
    │  │ └─ Local cache  │ │
    │  │                 │ │
    │  ├─ ROS 2 Apps     │ │
    │  ├─ Sensors        │ │
    │  └─ Real-time I/O  │ │
    │  └─────────────────┘ │
    └──────────────────────┘
```

## Quick Start (Local Kind Cluster)

### 1. Deploy CloudCore

```bash
cd /infra/modules/kubeedge-gateway

# Deploy KubeEdge CloudCore
bash deploy-kubeedge.sh

# Verify deployment
kubectl get pods -n kubeedge
kubectl get svc cloudcore -n kubeedge
```

Expected output:
```
NAME                         READY   STATUS    RESTARTS   AGE
cloudcore-69944df65f-8qs6r   1/1     Running   0          2m
```

### 2. Check CloudCore Endpoint

```bash
# Get CloudCore service IP
kubectl get svc cloudcore -n kubeedge -o jsonpath='{.spec.clusterIP}'
# Output: 10.96.77.2

# Check CloudCore status
python3 edge-node-manager.py status
```

### 3. Simulate an Edge Node with ROS2

```bash
# Create simulated edge node (pod-based, not real KubeEdge node)
python3 edge-node-manager.py simulate-edge \
  --node-name robot-edge-01 \
  --worker-node robotics-dev-worker \
  --domain-id 42

# This creates two resources:
# 1. robot-edge-01 (pod that sleeps - represents edge device)
# 2. ros2-talker-edge (deployment - ROS2 publisher on edge)
```

### 4. Verify Edge Simulation Running

```bash
# Check edge node pod
kubectl get pods -o wide | grep robot-edge-01
# Output: robot-edge-01  1/1  Running  10m  10.244.3.246

# Check ROS2 talker deployment
kubectl get pods -o wide | grep ros2-talker-edge
# Output: ros2-talker-edge-574747d94d-pwb5g  1/1  Running  10m

# View ROS2 messages being published
kubectl logs -f deployment/ros2-talker-edge -c talker

# Output:
# [INFO] [1763636906.911529887] [talker]: Publishing: 'Hello World: 612'
# [INFO] [1763636907.911371679] [talker]: Publishing: 'Hello World: 613'
```

### 5. Understand Registered vs Simulated

Important distinction:

```bash
# Simulated edge workloads (what we just created)
kubectl get pods -o wide | grep -E "robot-edge|ros2-talker-edge"
# These are pods on the control plane running ROS2

# Real edge nodes registered via KubeEdge
kubectl get nodes -o wide | grep -i edge
# Would show actual devices running EdgeCore daemon (keadm)

# CloudCore management layer
kubectl get pods -n kubeedge
# Shows CloudCore accepting incoming connections on ports 10000-10002
```

The simulation demonstrates ROS2 running on edge nodes. To connect real edge devices, see the "Real Edge Node Registration" section below.

## Production Deployment (AWS EKS)

### 1. Deploy CloudCore on EKS

```bash
# Get EKS cluster info
kubectl cluster-info

# Deploy CloudCore (uses same script)
bash deploy-kubeedge.sh

# Get LoadBalancer endpoint
kubectl get svc cloudcore -n kubeedge
# Note: EXTERNAL-IP will be an AWS NLB DNS
```

### 2. Expose CloudCore Publicly

```bash
# For on-premise edge nodes, expose via LoadBalancer or port-forward
CLOUDCORE_IP=$(kubectl get svc cloudcore -n kubeedge \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "CloudCore accessible at: $CLOUDCORE_IP:10000"
```

### 3. Join Edge Nodes from Remote Locations

```bash
# Generate join script for specific edge node
python3 edge-node-manager.py join-script \
  --node-name warehouse-robot-01 \
  --cloudcore-ip <EKS-CLOUDCORE-IP> \
  --output /tmp/join-warehouse.sh

# Copy to edge device and run
scp /tmp/join-warehouse.sh robot@192.168.1.100:/tmp/
ssh robot@192.168.1.100 '/tmp/join-warehouse.sh'
```

### 4. Schedule ROS 2 Pods on Edge

```bash
# Schedule on specific edge node
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-talker-warehouse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ros2-talker
  template:
    metadata:
      labels:
        app: ros2-talker
    spec:
      nodeSelector:
        kubernetes.io/hostname: warehouse-robot-01
      containers:
      - name: talker
        image: arm64v8/ros:humble
        command: ["/bin/bash"]
        args: ["-c", "source /opt/ros/humble/setup.bash && ros2 run demo_nodes_cpp talker"]
        env:
        - name: ROS_DOMAIN_ID
          value: "42"
        - name: ROS_LOCALHOST_ONLY
          value: "0"
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
EOF
```

## Understanding Edge Nodes vs Simulated Workloads

There are two ways to run edge workloads:

### 1. Simulated Edge Nodes (What We Demonstrated)

Kubernetes pods running on the control plane that simulate edge behavior:

```bash
# Create simulation
python3 edge-node-manager.py simulate-edge \
  --node-name robot-edge-01 \
  --worker-node robotics-dev-worker \
  --domain-id 42

# What this creates:
# - robot-edge-01: Pod sleeping in background (represents edge device)
# - ros2-talker-edge: Deployment publishing ROS2 messages

# View:
kubectl get pods -o wide | grep robot-edge
kubectl logs -f deployment/ros2-talker-edge -c talker
```

Advantages:
- No physical hardware needed
- Easy testing and development
- Same ROS2 application code as production

Limitations:
- No actual KubeEdge EdgeCore daemon
- No offline capability
- Not a real edge device

### 2. Real Edge Nodes (Production)

Physical devices or VMs running KubeEdge EdgeCore:

```bash
# On edge device, install and join:
keadm join --cloudcore-ipport=<CLOUDCORE-IP>:10000 \
  --edgenode-name=warehouse-robot-01 \
  --kubeedge-version=v1.15.0

# View registered nodes:
kubectl get nodes -o wide
# Shows real edge nodes in cluster
```

Advantages:
- Actual edge device integration
- Offline-capable with local caching
- Real-time data processing
- Device management via KubeEdge

## Management Commands

### CloudCore Status

```bash
# Check CloudCore pod
kubectl get deployment cloudcore -n kubeedge

# View logs
kubectl logs -f deployment/cloudcore -n kubeedge

# Check metrics
kubectl port-forward svc/cloudcore -n kubeedge 9000:9000
# Access: http://localhost:9000/metrics
```

### Edge Nodes

Check registered KubeEdge nodes (real devices only):

```bash
# List all registered edge nodes
kubectl get nodes -o wide | grep -i edge

# Get detailed node info
kubectl describe node <edge-node-name>

# For simulated edge workloads:
python3 edge-node-manager.py status

# Check CloudCore logs
kubectl logs -f deployment/cloudcore -n kubeedge
```

For real edge devices with EdgeCore running:

```bash
# View EdgeCore logs on device
ssh user@<edge-device>
journalctl -u edgecore -f
```

### ROS 2 Pods on Edge

```bash
# List pods on edge nodes
kubectl get pods -o wide | grep robot-edge

# Exec into pod on edge
kubectl exec -it <pod-name> -- bash

# Check ROS topics on edge
kubectl exec -it <pod-name> -- ros2 topic list

# Monitor resources on edge
kubectl top pods -l node-role.kubernetes.io/edge=true
```

## Configuration

### CloudCore Settings

Edit `/infra/modules/kubeedge-gateway/deploy-kubeedge.sh` to customize:

```yaml
modules:
  cloudHub:
    cloudHubPort: 10000              # WebSocket port
    cloudHubSecurePort: 10002        # HTTPS port
    
  eventBus:
    mqttServerPort: 1883             # MQTT broker port
    mqttInternalPort: 11883          # Internal MQTT
    
  deviceController:
    enable: true                     # Device management
    
  dynamicController:
    enable: true                     # Dynamic config
```

### Edge Node Configuration

Control edge behavior via environment variables or ConfigMaps:

```yaml
env:
- name: ROS_DOMAIN_ID
  value: "42"
- name: ROS_LOCALHOST_ONLY
  value: "0"
- name: RCUTILS_LOGGING_USE_STDOUT
  value: "1"
```

## Networking

### Ports

| Port | Protocol | Purpose | Direction |
|------|----------|---------|-----------|
| 10000 | WebSocket | Cloud-to-Edge | Bidirectional |
| 10001 | QUIC (UDP) | Fast tunnel | Bidirectional |
| 10002 | HTTPS (TCP) | Secure tunnel | Bidirectional |
| 1883 | TCP | MQTT broker | Internal |
| 9000 | TCP | Metrics | Internal |

### Firewall Rules (AWS Security Group)

```bash
# Allow edge nodes to connect to CloudCore
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 10000 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol udp \
  --port 10001 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 10002 \
  --cidr 0.0.0.0/0
```

## Troubleshooting

### CloudCore Won't Start

```bash
# Check logs
kubectl logs deployment/cloudcore -n kubeedge

# Common issues:
# 1. RBAC: cloudcore service account lacks permissions
# 2. Resources: insufficient CPU/memory
# 3. Config: invalid cloudcore.yaml syntax

# Fix RBAC
kubectl apply -f - << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudcore
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods", "nodes", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
EOF
```

### Edge Node Can't Connect

For real edge devices:

```bash
# SSH to edge device
ssh user@<edge-device>

# Check connectivity to CloudCore
telnet <CLOUDCORE-IP> 10000

# Check DNS resolution
nslookup cloudcore.kubeedge.svc.cluster.local

# Restart EdgeCore
sudo systemctl restart edgecore

# View EdgeCore logs
journalctl -u edgecore -n 100 --no-pager
```

For simulated workloads:

```bash
# Check pod network connectivity
kubectl exec -it robot-edge-01 -- ping 10.96.77.2

# Check CloudCore is listening
kubectl exec -it robot-edge-01 -- nc -zv 10.96.77.2 10000
```

### ROS 2 Pods Pending on Edge

```bash
# Check node resources
kubectl top node robot-edge-01

# Check pod events
kubectl describe pod <ros2-pod> -n default

# Check if edge node is ready
kubectl describe node robot-edge-01 | grep -A 5 Conditions

# Force reschedule
kubectl delete pod <ros2-pod>
# Kubernetes will reschedule automatically
```

### Network Issues Between Cloud and Edge

```bash
# Test cloud-to-edge connectivity
kubectl exec -it <cloud-pod> -- ping <edge-pod-ip>

# Test edge-to-cloud connectivity
docker exec <edge-container> ping <cloud-pod-ip>

# Check EdgeMesh status
kubectl get pods -n kubeedge | grep edgemesh

# Check network policies
kubectl get networkpolicies -A
```

## Integration with ROS 2

### Multiple Domains

Deploy separate ROS 2 domains for different applications:

```bash
# Domain 42: Main robotics stack
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-domain42
spec:
  template:
    spec:
      containers:
      - name: talker
        env:
        - name: ROS_DOMAIN_ID
          value: "42"
EOF

# Domain 43: IoT sensors
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-domain43
spec:
  template:
    spec:
      containers:
      - name: sensor
        env:
        - name: ROS_DOMAIN_ID
          value: "43"
EOF
```

### Cross-Edge Communication

Enable ROS 2 communication between edge nodes:

```bash
# Deploy listener on edge node 1
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-listener
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: robot-edge-01
      containers:
      - name: listener
        image: arm64v8/ros:humble
        command: ["/bin/bash"]
        args: ["-c", "source /opt/ros/humble/setup.bash && ros2 run demo_nodes_cpp listener"]
        env:
        - name: ROS_DOMAIN_ID
          value: "42"
EOF

# Deploy talker on edge node 2
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-talker
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: robot-edge-02
      containers:
      - name: talker
        image: arm64v8/ros:humble
        command: ["/bin/bash"]
        args: ["-c", "source /opt/ros/humble/setup.bash && ros2 run demo_nodes_cpp talker"]
        env:
        - name: ROS_DOMAIN_ID
          value: "42"
EOF
```

## Cleanup

### Remove Single Edge Node

```bash
# On edge node, reset KubeEdge
keadm reset --server=10.96.77.2:10000

# Remove from Kubernetes
kubectl delete node robot-edge-01

# Delete container
docker rm -f robot-edge-01
```

### Remove CloudCore

```bash
# Delete KubeEdge namespace
kubectl delete namespace kubeedge

# Or selectively delete
kubectl delete deployment cloudcore -n kubeedge
kubectl delete svc cloudcore -n kubeedge
```

## Performance Tuning

### Latency Optimization

```yaml
# Use QUIC (UDP) for lower latency
spec:
  cloudHub:
    quic:
      enable: true
      port: 10001
```

### Bandwidth Optimization

```yaml
# Enable compression
modules:
  cloudHub:
    websocket:
      maxMessageSize: 1000000  # 1MB
```

### Resource Limits

```bash
# Adjust CloudCore resources for high-load scenarios
kubectl set resources deployment cloudcore -n kubeedge \
  --limits=cpu=2,memory=2Gi \
  --requests=cpu=500m,memory=1Gi
```

## References

- **KubeEdge Official Docs**: https://kubeedge.io/en/docs/
- **KubeEdge GitHub**: https://github.com/kubeedge/kubeedge
- **EdgeMesh Guide**: https://edgemesh.netlify.app/
- **ROS 2 Documentation**: https://docs.ros.org/en/humble/
- **Kubernetes Documentation**: https://kubernetes.io/docs/

## Support

For issues:
1. Check CloudCore logs: `kubectl logs deployment/cloudcore -n kubeedge`
2. Check EdgeCore logs: `docker exec <container> journalctl -u edgecore`
3. File an issue on GitHub with logs attached
4. Join [KubeEdge Community Slack](https://cloud-native.slack.com)

## Tools

| Tool | Location | Purpose |
|------|----------|---------|
| `deploy-kubeedge.sh` | module/ | Deploy CloudCore |
| `edge-node-manager.py` | module/ | Manage edge nodes |
| `simulate-edge-node.sh` | module/ | Test with Docker |

## Contributing

To improve this guide:
1. Test deployments
2. Document issues and solutions
3. Update this file
4. Submit PR

---

**Last Updated**: November 2025  
**Status**: Production Ready  
**Maintainer**: Robotics Platform Team
