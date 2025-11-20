# KubeEdge Gateway Standalone Deployment

This deploys KubeEdge CloudCore independently from Terraform, allowing edge nodes to join your Kubernetes cluster.

## Architecture

```
┌─────────────────────────────────┐
│  Kubernetes Control Plane       │
│  (kind-local cluster)           │
├─────────────────────────────────┤
│  KubeEdge CloudCore             │
│  - CloudHub (WebSocket/QUIC)    │
│  - Device Controller            │
│  - MQTT Server                  │
├─────────────────────────────────┤
│  EdgeMesh                       │
│  (networking overlay)           │
└─────────────────────────────────┘
         ↕ (10000, 10001, 10002)
┌─────────────────────────────────┐
│  Edge Nodes (keadm)             │
│  - EdgeCore daemon              │
│  - Local containers             │
└─────────────────────────────────┘
```

## Prerequisites

- Kubernetes cluster running (kind-local)
- `kubectl` configured
- `helm` installed
- `docker` installed (for image pulling)

## Quick Start

### 1. Deploy CloudCore

```bash
# Make script executable
chmod +x /Users/sqe/interviews/tf/infra/modules/kubeedge-gateway/deploy-kubeedge.sh

# Run deployment
/Users/sqe/interviews/tf/infra/modules/kubeedge-gateway/deploy-kubeedge.sh
```

### 2. Get CloudCore Access Info

```bash
# Get LoadBalancer IP/hostname
kubectl get svc cloudcore -n kubeedge

# Example output:
# NAME         TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)
# cloudcore    LoadBalancer   10.96.x.x    <pending>     10000:32xxx/TCP...

# For kind clusters, use port-forward or node IP:
kubectl port-forward svc/cloudcore -n kubeedge 10000:10000 10001:10001 10002:10002 &
CLOUDCORE_IP="localhost"
```

### 3. Join Edge Node

On an edge machine (Linux, ARM64 or x86_64):

```bash
# Download keadm
KUBEEDGE_VERSION="1.15.0"
curl -L https://github.com/kubeedge/kubeedge/releases/download/v${KUBEEDGE_VERSION}/keadm-v${KUBEEDGE_VERSION}-linux-arm64 \
  -o /tmp/keadm && chmod +x /tmp/keadm

# Join the cluster
/tmp/keadm join --cloudcore-ipport=$CLOUDCORE_IP:10000 \
  --edgenode-name=robot-edge-01 \
  --kubeedge-version=v${KUBEEDGE_VERSION}
```

### 4. Verify Edge Node

```bash
# On control plane
kubectl get nodes -o wide

# Should show edge node with status Ready
# NAME             STATUS   ROLES    AGE    VERSION
# robotics-dev-... Ready    <none>   2m     v1.15.0-kubeedge

# Check CloudCore logs
kubectl logs -f deployment/cloudcore -n kubeedge
```

## Deploying ROS2 Apps on Edge Nodes

Once edge nodes join, schedule ROS2 containers there:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ros2-talker-edge
spec:
  selector:
    matchLabels:
      app: ros2-talker-edge
  template:
    metadata:
      labels:
        app: ros2-talker-edge
    spec:
      # Force scheduling on edge nodes
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
        env:
        - name: ROS_DOMAIN_ID
          value: "42"
```

## Configuration

### CloudCore Config
Edit `/Users/sqe/interviews/tf/infra/modules/kubeedge-gateway/kubeedge-values.yaml` to customize:
- MQTT server settings
- Device model support
- Metrics collection
- Edge node authentication

### Monitoring

```bash
# Prometheus metrics available on port 9000
curl http://localhost:9000/metrics | grep kubeedge

# Grafana dashboard (if monitoring installed)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Then add endpoint: http://cloudcore.kubeedge:9000
```

## Troubleshooting

### Edge node fails to join
```bash
# Check CloudCore is accessible
telnet $CLOUDCORE_IP 10000

# Check CloudCore logs
kubectl logs deployment/cloudcore -n kubeedge --tail=100

# Verify firewall allows ports 10000-10002
```

### Edge node shows NotReady
```bash
# SSH to edge node and check EdgeCore
journalctl -u edgecore -f

# Restart EdgeCore
sudo systemctl restart edgecore
```

### Communication issues between edge and cloud
```bash
# Check EdgeMesh deployment
kubectl get pods -n kubeedge -l app=edgemesh

# Verify DNS from edge node
nslookup cloudcore.kubeedge.svc.cluster.local
```

## Cleanup

```bash
# Remove edge node
keadm reset --server=$CLOUDCORE_IP:10000

# Remove KubeEdge from cluster
helm uninstall edgemesh -n kubeedge
kubectl delete deployment cloudcore -n kubeedge
kubectl delete namespace kubeedge
```

## References

- [KubeEdge Official Docs](https://kubeedge.io/en/docs/)
- [EdgeMesh Guide](https://edgemesh.netlify.app/)
- [KubeEdge on GitHub](https://github.com/kubeedge/kubeedge)
- [OpenStack Ansible Automation](https://github.com/Function-Delivery-Network/KubeEdge-Openstack-Ansible-Automation)
