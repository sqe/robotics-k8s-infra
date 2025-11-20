# Quick Start - Ansible (KinD Local Deployment)

Get a fully functional robotics platform running locally in 5-10 minutes using Ansible instead of Terraform.

## Prerequisites

Install required tools:

```bash
# macOS
brew install kind kubectl helm ansible python3

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y curl git python3 python3-pip
pip3 install ansible
curl -fsSLo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x /usr/local/bin/kind
# ... install kubectl, helm from their official docs

# Verify installations
kind --version
kubectl version --client
helm version
ansible --version
```

Install Ansible collections:

```bash
ansible-galaxy collection install kubernetes.core
```

## One-Command Deployment

Deploy everything (KinD cluster + KubeEdge + ArgoCD + ROS2) in one command:

```bash
cd infra/ansible
ansible-playbook playbooks/site.yml
```

Or using Make:

```bash
make kind-deploy
```

This will:
1. Create a KinD cluster (3 control planes + 6 workers)
2. Install Cilium CNI with Hubble observability
3. Deploy KubeEdge CloudCore
4. Deploy ArgoCD for GitOps
5. Deploy ROS2 applications with multi-domain DDS

**Time:** 5-10 minutes depending on internet speed and system specs.

## Step-by-Step Deployment

If you prefer to deploy components individually:

### 1. Create KinD Cluster (3 min)

```bash
cd infra/ansible
ansible-playbook playbooks/provision-kind-cluster.yml
```

Customization:
```bash
ansible-playbook playbooks/provision-kind-cluster.yml \
  -e "cluster_name=my-cluster control_plane_count=1 worker_node_count=3"
```

### 2. Deploy KubeEdge CloudCore (2 min)

```bash
ansible-playbook playbooks/deploy-kubeedge.yml
```

### 3. Deploy ArgoCD (2 min)

```bash
ansible-playbook playbooks/deploy-argocd.yml
```

### 4. Deploy ROS2 Apps (1 min)

```bash
ansible-playbook playbooks/deploy-ros2.yml
```

## Verify Deployment

Check cluster status:

```bash
# View nodes
kubectl get nodes -o wide

# View all pods
kubectl get pods -A

# View KubeEdge
kubectl get pods -n kubeedge

# View ArgoCD
kubectl get pods -n argocd

# View ROS2 apps
kubectl get pods -l ros-domain=42
```

Expected pods:
```
NAMESPACE              NAME                                 READY   STATUS    RESTARTS
kubeedge               cloudcore-xxxxxxx-xxxxx              1/1     Running   0
argocd                 argocd-server-xxxxx                  1/1     Running   0
argocd                 argocd-repo-server-xxxxx             1/1     Running   0
argocd                 argocd-application-controller-xxxxx  1/1     Running   0
default                fastdds-discovery-server-xxxxx       1/1     Running   0
default                ros2-talker-cloud-xxxxx              1/1     Running   0
default                ros2-listener-cloud-xxxxx            1/1     Running   0
default                iot-sensor-node-xxxxx                1/1     Running   0
```

## Monitor ROS2 Communication

Watch ROS2 talker publishing messages:

```bash
kubectl logs -f deployment/ros2-talker-cloud
```

Expected output:
```
[INFO] [1763636906.911529887] [talker]: Publishing: 'Hello World: 612'
[INFO] [1763636907.911371679] [talker]: Publishing: 'Hello World: 613'
...
```

Watch ROS2 listener receiving messages:

```bash
kubectl logs -f deployment/ros2-listener-cloud
```

Expected output:
```
[INFO] [1763636906.912529887] [listener]: I heard: [Hello World: 612]
[INFO] [1763636907.912371679] [listener]: I heard: [Hello World: 613]
...
```

## Access ArgoCD UI

Port forward to your local machine:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
```

Open in browser: **https://localhost:8080**

Credentials:
- Username: `admin`
- Password: `argocd` (or get from secret):
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

## Register Edge Node

After CloudCore is running, register a real edge device:

1. Get CloudCore IP:
   ```bash
   kubectl get svc cloudcore -n kubeedge
   ```

2. On edge device, run the join script:
   ```bash
   scp /tmp/join-edge-node.sh <device>:/tmp/
   ssh <device> '/tmp/join-edge-node.sh robot-edge-01 <cloudcore-ip> 10000'
   ```

3. Verify on control plane:
   ```bash
   kubectl get nodes -o wide | grep robot-edge
   ```

## Test Edge Simulation (Localhost Only)

Simulate an edge node without needing a physical device:

```bash
# Using the edge-node-manager CLI from terraform setup
python3 edge-node-manager.py simulate-edge \
  --node-name robot-edge-01 \
  --worker-node robotics-dev-worker-2 \
  --domain-id 42

# Verify
kubectl get pods -n default | grep robot-edge-01
```

## Common Tasks

### Check cluster health

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get events -A --sort-by='.lastTimestamp'
```

### Monitor resource usage

```bash
kubectl top nodes
kubectl top pods -A
```

### View application logs

```bash
# KubeEdge
kubectl logs -f deployment/cloudcore -n kubeedge

# ArgoCD
kubectl logs -f deployment/argocd-server -n argocd

# ROS2 Talker
kubectl logs -f deployment/ros2-talker-cloud

# All pods in namespace
kubectl logs -f -n kubeedge --all-containers=true
```

### Shell into ROS2 pod

```bash
POD=$(kubectl get pods -l app=ros2-talker -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- bash

# Inside pod:
source /opt/ros/humble/setup.bash
ros2 topic list
ros2 topic echo /chatter
```

### Exec into pod

```bash
kubectl exec -it <pod-name> -- bash
```

## Troubleshooting

### KinD not starting

```bash
# Verify Docker is running
docker ps

# Check if cluster exists
kind get clusters

# Delete and retry
kind delete cluster --name robotics-dev
make kind-cluster
```

### CloudCore pod not ready

```bash
# Check pod status
kubectl describe pod -n kubeedge -l app=kubeedge

# Check logs
kubectl logs -f deployment/cloudcore -n kubeedge

# Check resource availability
kubectl describe nodes
```

### ArgoCD UI not accessible

```bash
# Verify service exists
kubectl get svc -n argocd

# Check pod status
kubectl get pods -n argocd -o wide

# Check logs
kubectl logs -f deployment/argocd-server -n argocd

# Try port forward again
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### ROS2 pods not communicating

```bash
# Verify both on same domain
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].env[?(@.name=="ROS_DOMAIN_ID")].value}'

# Check FastDDS discovery server is running
kubectl get pods | grep fastdds

# Check logs for errors
kubectl logs deployment/ros2-talker-cloud
kubectl logs deployment/ros2-listener-cloud
```

## Cleanup

### Delete everything

```bash
# Delete KinD cluster (all resources deleted)
make kind-destroy

# Or manually
kind delete cluster --name robotics-dev
```

### Delete specific components

```bash
# Remove KubeEdge only
kubectl delete namespace kubeedge

# Remove ArgoCD only
kubectl delete namespace argocd

# Remove ROS2 apps only
kubectl delete deployment -l ros-domain
```

## Using Make Commands

Convenience make targets for KinD deployment:

```bash
# Full deployment
make kind-deploy

# Individual components
make kind-cluster      # Just create cluster
make kind-kubeedge     # Add KubeEdge
make kind-argocd       # Add ArgoCD
make kind-ros2         # Add ROS2

# Delete
make kind-destroy

# General kubectl commands
make get-pods
make get-nodes
make cluster-info
make get-services
```

## Next Steps

1. **Explore the platform:**
   - Check all pods are running
   - View ROS2 logs
   - Access ArgoCD UI

2. **Register real edge nodes:**
   - Set up Raspberry Pi or Jetson device
   - Run the join script
   - Deploy ROS2 workloads

3. **Customize applications:**
   - Modify apps in `apps/base/`
   - Redeploy with `kubectl apply -k apps/base/`
   - Track with ArgoCD

4. **Production hardening:**
   - Use real TLS certificates
   - Set ArgoCD admin password
   - Enable network policies
   - Configure persistent storage

## Documentation

- **Full Ansible guide:** [infra/ansible/README.md](infra/ansible/README.md)
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **KubeEdge guide:** [KUBEEDGE_GUIDE.md](KUBEEDGE_GUIDE.md)
- **Implementation:** [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

## Comparison: Terraform vs Ansible

Both approaches support the same platform, choose based on your team's preference:

```
Feature              Terraform    Ansible
-------------------------------------------
State management     Yes          No (idempotent)
Multi-cloud          Yes          Yes
Modularity           Modules      Playbooks
Learning curve       Moderate     Easy for ops
YAML config          No (HCL)     Yes
KinD support         Yes          Yes
Local development    Yes          Yes
AWS production       Yes          (manual setup)
```

**Use Ansible for:** Local dev, ops teams familiar with YAML, simple deployments

**Use Terraform for:** Production, multi-cloud, state management, IaC best practices

## Support

For issues:
1. Check kubeconfig is accessible: `kubectl cluster-info`
2. Verify tools are installed: `make versions`
3. Run with verbose: `ansible-playbook -vvv playbooks/site.yml`
4. Check logs in respective namespaces
5. See full documentation: [infra/ansible/README.md](infra/ansible/README.md)

---

Built with Ansible for simplicity. Enjoy your robotics platform!
