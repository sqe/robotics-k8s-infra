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
│  ┌────────────────────────────────┐ │
│  │   KubeEdge CloudCore           │ │
│  │  ├─ CloudHub (WebSocket)       │ │
│  │  │  ├─ Port 10000              │ │
│  │  │  └─ Cloud-to-Edge tunnel    │ │
│  │  │                              │ │
│  │  ├─ QUIC (Fast lane)           │ │
│  │  │  ├─ Port 10001              │ │
│  │  │  └─ Optimized tunnel        │ │
│  │  │                              │ │
│  │  ├─ HTTPS (Secure)             │ │
│  │  │  └─ Port 10002              │ │
│  │  │                              │ │
│  │  └─ EventBus (MQTT)            │ │
│  │     ├─ Port 1883               │ │
│  │     └─ Message broker          │ │
│  └────────────────────────────────┘ │
│                                      │
└──────────────────────────────────────┘
           ▲   ▲   ▲
       TLS WebSocket QUIC
           │   │   │
    ┌──────┴───┴───┴──────┐
    │   Network (Internet) │
    └──────┬───┬───┬──────┘
           │   │   │
    ┌──────▼───▼───▼──────┐
    │  Edge Nodes (Robots) │
    │  ┌─────────────────┐ │
    │  │  EdgeCore       │ │
    │  │ ├─ Sync state   │ │
    │  │ ├─ Run pods     │ │
    │  │ └─ Local cache  │ │
    │  │                 │ │
    │  ├─ ROS 2 Apps    │ │
    │  ├─ Sensors       │ │
    │  └─ Real-time I/O │ │
    │  └─────────────────┘ │
    └─────────────────────┘
```

## Quick Start (Local Kind Cluster)

### 1. Deploy CloudCore

```bash
cd /Users/sqe/interviews/tf/infra/modules/kubeedge-gateway

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
kubectl get svc cloudcore -n kubeedge -o jsonpath='{.spec.clusterIP}'
# Output: 10.96.77.2
```

### 3. Simulate an Edge Node

```bash
# Start a simulated robot/edge device
bash simulate-edge-node.sh robot-edge-01 10.96.77.2 10000

# Wait 30-60 seconds for EdgeCore to initialize
sleep 60

# Check if edge node joined
kubectl get nodes -o wide
```

Should show:
```
NAME             STATUS   ROLES    AGE   VERSION
robot-edge-01    Ready    <none>   45s   v1.15.0-kubeedge
```

### 4. Deploy ROS 2 on Edge Node

```bash
# Generate ROS 2 deployment
python3 edge-node-manager.py deploy-ros2 \
  --app-name ros2-talker \
  --image arm64v8/ros:humble \
  --domain-id 42 \
  --output /tmp/talker-edge.yaml

# Deploy to edge node
kubectl apply -f /tmp/talker-edge.yaml

# Check pod status
kubectl get pods -o wide | grep talker-edge
```

### 5. Verify ROS 2 Running on Edge

```bash
# Check pod logs
kubectl logs -l app=ros2-talker-edge

# Should see: Publishing messages...
```

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

```bash
# List all edge nodes
python3 edge-node-manager.py list

# Check edge node status
python3 edge-node-manager.py status

# Get detailed node info
kubectl describe node <edge-node-name>

# Check EdgeCore logs (inside container)
docker exec <edge-container> journalctl -u edgecore -f
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

Edit `/Users/sqe/interviews/tf/infra/modules/kubeedge-gateway/deploy-kubeedge.sh` to customize:

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

```bash
# Check connectivity to CloudCore
docker exec <edge-container> \
  curl -v telnet://10.96.77.2:10000

# Check DNS resolution
docker exec <edge-container> \
  nslookup cloudcore.kubeedge.svc.cluster.local

# Check firewall
docker exec <edge-container> \
  telnet 10.96.77.2 10000

# Restart EdgeCore
docker exec <edge-container> \
  systemctl restart edgecore
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
