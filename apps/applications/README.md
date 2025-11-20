# ArgoCD Applications

This directory contains ArgoCD Application manifests for deploying various components to the cluster.

## Files

- **core-apps.yaml** - Core platform apps (robotics-platform, kube-prometheus-stack)
- **ros2-apps.yaml** - ROS 2 workloads (ros2-talker, ros2-listener)

## Deployment

Apply all applications:

```bash
kubectl apply -f apps/applications/
```

Or apply individually:

```bash
kubectl apply -f apps/applications/core-apps.yaml
kubectl apply -f apps/applications/ros2-apps.yaml
```

## Monitoring Application

The `kube-prometheus-stack` is deployed via the `core-apps.yaml` file.
It provides:
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for alerting

Access Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Then visit http://localhost:3000
```
