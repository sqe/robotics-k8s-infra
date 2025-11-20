# KubeEdge Gateway Module

Standalone deployment of KubeEdge CloudCore with EdgeMesh for managing edge/IoT devices in your Kubernetes cluster.

This module is designed to work **independently** from Terraform to avoid state drift issues while your control plane is running.

## Quick Start

```bash
cd /Users/sqe/interviews/tf/infra/modules/kubeedge-gateway

# Deploy KubeEdge CloudCore
bash deploy-kubeedge.sh

# Check status
python3 edge-node-manager.py status

# Join an edge node
CLOUDCORE_IP=$(kubectl get svc cloudcore -n kubeedge -o jsonpath='{.spec.clusterIP}')
python3 edge-node-manager.py join-script \
  --node-name robot-edge-01 \
  --cloudcore-ip $CLOUDCORE_IP \
  --output /tmp/join-robot.sh
```

## Components

| File | Purpose |
|------|---------|
| `deploy-kubeedge.sh` | Main deployment script for CloudCore + EdgeMesh |
| `edge-node-manager.py` | Python CLI for managing edge nodes |
| `kubeedge-values.yaml` | Helm values for configuration |
| `DEPLOYMENT.md` | Detailed deployment guide |
| `main.tf` | Original Terraform module (for reference only) |

## Deployment Overview

### CloudCore Components
- **CloudHub**: WebSocket/QUIC endpoints for edge nodes (ports 10000-10002)
- **EventBus**: MQTT server for message passing
- **Device Controller**: Manages IoT devices
- **Dynamic Controller**: Handles dynamic configuration

### EdgeMesh
- Provides networking overlay for cloud-edge communication
- Enables service discovery across cloud and edge

## Usage

### 1. Deploy CloudCore
```bash
bash deploy-kubeedge.sh
```

### 2. Monitor Deployment
```bash
kubectl get pods -n kubeedge
kubectl logs -f deployment/cloudcore -n kubeedge
```

### 3. Join Edge Nodes
```bash
# Get CloudCore IP (for kind, use localhost with port-forward)
kubectl port-forward svc/cloudcore -n kubeedge 10000:10000 10001:10001 10002:10002 &

# Generate and run join script
python3 edge-node-manager.py join-script \
  --node-name my-robot \
  --cloudcore-ip localhost

# On edge node, run the generated script
```

### 4. Deploy ROS2 Apps on Edge
```bash
# Generate ROS2 deployment with edge node affinity
python3 edge-node-manager.py deploy-ros2 \
  --app-name ros2-talker \
  --image arm64v8/ros:humble \
  --domain-id 42 \
  --output talker-edge.yaml

# Apply to cluster
kubectl apply -f talker-edge.yaml
```

## Configuration

Edit `kubeedge-values.yaml` to customize:
- CloudCore replica count
- Resource limits
- MQTT settings
- Metrics collection
- Device model support

Then redeploy:
```bash
bash deploy-kubeedge.sh
```

## Integration with ROS2 Platform

### Architecture
```
┌──────────────────────┐
│  Control Plane       │
│  (kind-local)        │
│  - ArgoCD            │
│  - KubeEdge Core     │
│  - ROS2 apps         │
└──────────────────────┘
         ↑
         │ 10000-10002
         │
    EdgeMesh
         │
         ↓
┌──────────────────────┐
│  Edge Nodes          │
│  (Robots, IoT)       │
│  - EdgeCore          │
│  - ROS2 containers   │
└──────────────────────┘
```

### Deploy ROS2 Talker on Edge
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-talker-robot
spec:
  selector:
    matchLabels:
      app: ros2-talker-robot
  template:
    metadata:
      labels:
        app: ros2-talker-robot
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/edge
                operator: In
                values:
                - "true"
      
      containers:
      - name: talker
        image: arm64v8/ros:humble
        command:
          - /bin/bash
          - -c
          - |
            source /opt/ros/humble/setup.bash
            ros2 run demo_nodes_cpp talker
        env:
        - name: ROS_DOMAIN_ID
          value: "42"
        - name: ROS_LOCALHOST_ONLY
          value: "0"
```

## Troubleshooting

### CloudCore won't start
```bash
# Check logs
kubectl logs deployment/cloudcore -n kubeedge

# Check resource limits
kubectl top nodes
kubectl top pods -n kubeedge

# Restart
kubectl rollout restart deployment/cloudcore -n kubeedge
```

### Edge node can't connect
```bash
# Verify connectivity to CloudCore
telnet <cloudcore-ip> 10000

# Check edge node logs
journalctl -u edgecore -f

# Verify firewall
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=10000-10002/tcp --permanent
```

### ROS2 communication fails
```bash
# Check EdgeMesh
kubectl get pods -n kubeedge | grep edgemesh

# Verify DNS
kubectl exec -it <edge-pod> -- nslookup cloudcore.kubeedge.svc.cluster.local

# Check ROS_DOMAIN_ID matches
kubectl get deploy -o jsonpath='{.items[*].spec.template.spec.containers[*].env[?(@.name=="ROS_DOMAIN_ID")].value}'
```

## Cleanup

```bash
# Remove edge nodes first
keadm reset --server=<cloudcore-ip>:10000

# Delete KubeEdge from cluster
kubectl delete namespace kubeedge

# Verify cleanup
kubectl get nodes -o wide
```

## References

- [KubeEdge Documentation](https://kubeedge.io/en/docs/)
- [EdgeMesh Guide](https://edgemesh.netlify.app/)
- [KubeEdge GitHub Repository](https://github.com/kubeedge/kubeedge)
- [Function-Delivery-Network KubeEdge-OpenStack Automation](https://github.com/Function-Delivery-Network/KubeEdge-Openstack-Ansible-Automation)

## Important Notes

⚠️ **Not Terraform-Managed**: This module deploys KubeEdge outside of Terraform to prevent state conflicts. All operations are manual via kubectl and scripts.

⚠️ **Network Requirements**: Ensure ports 10000-10002 are accessible from edge nodes to control plane.

⚠️ **Edge Node Requirements**: 
- Linux kernel 4.8+
- Docker or containerd
- At least 100MB free disk space
- ARM64 or x86_64 architecture

## Support

For issues with:
- **KubeEdge**: See https://github.com/kubeedge/kubeedge/issues
- **ROS2**: See https://github.com/ros2/ros2/wiki
- **EdgeMesh**: See https://github.com/kubeedge/edgemesh/issues
