# Quick Start: Deploy Robotics Cluster on AWS

Get up and running in 30 minutes.

## Prerequisites

```bash
# Check versions
terraform version          # >= 1.0
ansible --version         # >= 2.9
kubectl version --client   # >= 1.28
aws --version             # >= 2.0
helm version              # >= 3.10

# AWS credentials
aws configure
export AWS_REGION=us-west-2
```

## Step 1: Deploy Infrastructure (5 min)

```bash
cd infra/environments/development/robotics-prod

# Initialize
terraform init

# Review what will be created
terraform plan

# Deploy
terraform apply

# Save outputs
terraform output -json > outputs.json
```

## Step 2: Update Ansible Inventory (2 min)

```bash
cd ../../ansible

# Generate inventory from Terraform outputs
cat > inventory-generated.yml << EOF
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    ansible_python_interpreter: /usr/bin/python3
  children:
    k8s_control_plane:
      hosts:
        k8s-cp-1:
          ansible_host: $(terraform output -raw control_plane_ips | jq -r '.[0]')
        k8s-cp-2:
          ansible_host: $(terraform output -raw control_plane_ips | jq -r '.[1]')
        k8s-cp-3:
          ansible_host: $(terraform output -raw control_plane_ips | jq -r '.[2]')
    k8s_workers:
      hosts:
        k8s-worker-1:
          ansible_host: $(terraform output -raw worker_node_ips | jq -r '.[0]')
        k8s-worker-2:
          ansible_host: $(terraform output -raw worker_node_ips | jq -r '.[1]')
        k8s-worker-3:
          ansible_host: $(terraform output -raw worker_node_ips | jq -r '.[2]')
EOF
```

## Step 3: Provision Control Plane (10 min)

```bash
# Deploy Kubernetes control plane
ansible-playbook playbooks/provision-control-plane.yml

# Wait for initialization
sleep 30

# Check status
kubectl get nodes
```

## Step 4: Join Worker Nodes (8 min)

```bash
# Get join command from control plane
CONTROLLER=$(ansible-inventory -i inventory-generated.yml --host k8s-cp-1 | jq -r '.ansible_host')
JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no ubuntu@$CONTROLLER sudo kubeadm token create --print-join-command)

# Provision workers
ansible-playbook playbooks/provision-worker-nodes.yml

# Verify all nodes
kubectl get nodes -o wide
```

## Step 5: Deploy CNI (3 min)

```bash
# Deploy Cilium for networking
ansible-playbook playbooks/deploy-cni.yml

# Wait for CNI
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s
```

## Step 6: Deploy KubeEdge (2 min)

```bash
# Deploy KubeEdge CloudCore
ansible-playbook playbooks/deploy-kubeedge.yml

# Verify
kubectl get pods -n kubeedge
```

## Step 7: Deploy ROS 2 (2 min)

```bash
# Deploy ROS 2 workloads
ansible-playbook playbooks/deploy-ros2.yml

# Verify
kubectl get pods -n ros2-workloads
```

## Verification

```bash
# Check all nodes
kubectl get nodes -A

# Check pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Test ROS 2
POD=$(kubectl get pods -n ros2-workloads -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -n ros2-workloads -- ros2 --version
```

## Common Tasks

### Access Cluster Remotely

```bash
# Get kubeconfig
cd infra/environments/development/robotics-prod
terraform output -raw kubeconfig > ~/.kube/robotics-config
export KUBECONFIG=~/.kube/robotics-config

# Verify access
kubectl get nodes
```

### Check Cluster Status

```bash
# Control plane
kubectl get pods -n kube-system

# KubeEdge
kubectl get pods -n kubeedge

# ROS 2
kubectl get pods -n ros2-workloads

# Storage (RDS)
aws rds describe-db-clusters --query 'DBClusters[*].[DBClusterIdentifier,Status]'
```

### View Logs

```bash
# CloudCore logs
kubectl logs -n kubeedge -l app=cloudcore -f

# ROS 2 logs
kubectl logs -n ros2-workloads -l app=ros2-workload -f

# kubelet logs on node
ssh ubuntu@<node-ip> sudo journalctl -u kubelet -f
```

### Scale Deployments

```bash
# Scale ROS 2 to 3 replicas
kubectl scale deployment ros2-node -n ros2-workloads --replicas=3

# Check status
kubectl get deployment -n ros2-workloads
```

### Register Edge Node

```bash
# Get token from CloudCore
TOKEN=$(kubectl exec -n kubeedge -it pod/cloudcore-xxx -- keadm gettoken)

# On edge device
curl -k https://cloud.api.endpoint:10002 --cert cert.pem --key key.pem \
  -H "Authorization: Bearer $TOKEN"

# Then join
keadm join \
  --cloudcore-ipport=cloud.api.endpoint:10000 \
  --edgenode-name=edge-device-1 \
  --token=$TOKEN
```

## Troubleshooting

### Nodes Not Ready

```bash
# Check kubelet
kubectl describe node <node-name>

# Check logs
ssh ubuntu@<node-ip> sudo journalctl -u kubelet -n 50

# Restart kubelet
ssh ubuntu@<node-ip> sudo systemctl restart kubelet
```

### Pods Pending

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check resources
kubectl top nodes
kubectl top pods -A

# Check PVC
kubectl get pvc -A
```

### Network Issues

```bash
# Test DNS
kubectl exec -it <pod> -- nslookup kubernetes.default

# Test connectivity
kubectl exec -it <pod1> -- ping <pod2-ip>

# Check network policies
kubectl get networkpolicies -A
```

## Next Steps

1. **Configure monitoring:** Deploy Prometheus and Grafana
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack
   ```

2. **Setup backup:** Configure automated backups
   ```bash
   terraform apply -target=aws_backup_vault.cluster
   ```

3. **Deploy applications:** Create your ROS 2 packages
   ```bash
   helm install my-ros-app ./charts/my-ros-app
   ```

4. **Configure GitOps:** Setup ArgoCD for continuous deployment
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm install argocd argo/argo-cd
   ```

## Cleanup

```bash
# Destroy everything
cd infra/environments/development/robotics-prod
terraform destroy

# Confirm destruction
aws ec2 describe-instances --filters "Name=tag:Environment,Values=production" --query 'Reservations[].Instances[].[InstanceId,State.Name]'
```

## Performance Benchmarks

Typical deployment times:
- Infrastructure provisioning: 5-10 minutes
- Control plane initialization: 5-10 minutes
- Worker node join: 3-5 minutes per node
- CNI deployment: 2-5 minutes
- KubeEdge setup: 2-3 minutes
- ROS 2 deployment: 1-2 minutes

**Total: ~25-40 minutes for 6-node cluster**

## Costs

Estimated monthly costs (on-demand, us-west-2):
- 3x m6g.large (control plane): ~$110/month
- 3x t4g.large (workers): ~$50/month
- RDS Aurora (Multi-AZ): ~$150/month
- Data transfer: ~$20/month
- **Total: ~$330/month** (40% cheaper with SPOT instances)

## Getting Help

- Kubernetes docs: https://kubernetes.io/docs/
- KubeEdge docs: https://kubeedge.io/docs/
- ROS 2 docs: https://docs.ros.org/en/humble/
- Issue tracker: GitHub Issues in this repo
- Community: https://kubernetes.slack.com, https://ros.org/support/

---

**Need help?** Check the detailed [ROBOTICS_DEPLOYMENT.md](./ROBOTICS_DEPLOYMENT.md) guide.
