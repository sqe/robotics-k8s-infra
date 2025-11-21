# Robotics Automation Platform - Architecture

## System Overview

A production-grade, fully-automated infrastructure-as-code solution for deploying containerized robotics applications on Kubernetes with edge computing capabilities via KubeEdge.

### Design Principles

1. **Infrastructure as Code (IaC):** Everything defined in Terraform
2. **GitOps Ready:** ArgoCD integration for continuous deployment
3. **High Availability:** Multi-AZ deployment with 3+ nodes
4. **Edge Computing:** KubeEdge for seamless cloud-edge communication
5. **ROS 2 Native:** Full DDS support for robot middleware
6. **Observability:** Built-in logging, monitoring, and tracing
7. **Scalability:** Auto-scaling from 3 to 100+ nodes
8. **Security:** RBAC, network policies, encryption in transit

## Technology Stack

```
┌──────────────────────────────────────────────────────────────┐
│                         User Layer                           │
├──────────────────────────────────────────────────────────────┤
│  Applications (ROS 2 packages, Robotics workloads)           │
├──────────────────────────────────────────────────────────────┤
│                    Container Orchestration                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Kubernetes 1.28+                                       │ │
│  │  - Control Plane (3 HA nodes)                           │ │
│  │  - Worker Nodes (3-100+ nodes)                          │ │
│  │  - etcd (distributed state)                             │ │
│  │  - kube-proxy (networking)                              │ │
│  └─────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────┤
│                  Networking & Service Mesh                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Cilium (or Flannel) - CNI                              │ │
│  │  - eBPF networking                                      │ │
│  │  - Network policies                                     │ │
│  │  - Encrypted communications                             │ │
│  └─────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────┤
│                    Edge Computing Layer                      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  KubeEdge (Cloud + Edge)                                │ │
│  │  - CloudCore (cloud side)                               │ │
│  │  - EdgeCore (edge nodes)                                │ │
│  │  - MQTT broker for messaging                            │ │
│  └─────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────┤
│                    Robotics Middleware                       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  ROS 2 (Humble)                                         │ │
│  │  - DDS middleware (micro-XRCE-DDS or FastDDS)           │ │
│  │  - Node management                                      │ │
│  │  - Service/Action discovery                             │ │
│  └─────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────┤
│                    Infrastructure as Code                    │
│  ┌──────────────────┬──────────────────────────────────────┐ │
│  │    Terraform     │         Ansible                      │ │
│  │  ┌────────────┐  │  ┌─────────────────────────────────┐ │ │
│  │  │ AWS        │  │  │ - Node provisioning             │ │ │
│  │  │ - VPC      │  │  │ - Kubernetes setup              │ │ │
│  │  │ - ECS/EC2  │  │  │ - Container runtime             │ │ │
│  │  │ - RDS      │  │  │ - CNI deployment                │ │ │
│  │  │ - Route53  │  │  │ - KubeEdge setup                │ │ │
│  │  │ - Security │  │  │ - ROS 2 deployment              │ │ │
│  │  └────────────┘  │  └─────────────────────────────────┘ │ │
│  └──────────────────┴──────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Cloud Infrastructure (AWS)

```
AWS Account
├── VPC (10.0.0.0/16)
│   ├── 3 Public Subnets (NAT gateways)
│   ├── 3 Private Subnets (Kubernetes nodes)
│   ├── Internet Gateway
│   ├── NAT Gateways (1 per AZ for HA)
│   └── Route Tables
├── Security Groups
│   ├── Control Plane SG
│   ├── Worker Nodes SG
│   └── RDS SG
├── Route53
│   ├── Internal Hosted Zone (robotics.local)
│   └── Records for all nodes
├── RDS Aurora PostgreSQL
│   ├── Multi-AZ cluster (3+ instances)
│   ├── Automated backups
│   └── Read replicas
└── IAM Roles
    ├── Control plane role
    ├── Worker node role
    └── KubeEdge role
```

### 2. Kubernetes Cluster

```
Kubernetes Cluster
├── Control Plane (High Availability)
│   ├── kube-apiserver (3 replicas, load balanced)
│   ├── etcd cluster (3-5 nodes)
│   ├── kube-scheduler (3 replicas)
│   ├── kube-controller-manager (3 replicas)
│   └── cloud-controller-manager
├── Worker Nodes
│   ├── kubelet (agent on each node)
│   ├── kube-proxy (networking)
│   ├── Container runtime (Docker/containerd)
│   └── Node-local dns cache
├── Add-ons
│   ├── CoreDNS (service discovery)
│   ├── Cilium/Flannel (CNI)
│   ├── KubeEdge (cloud-edge)
│   └── Metrics server (resource usage)
└── Applications
    ├── ROS 2 workloads
    ├── Edge connectors
    └── Monitoring stack
```

### 3. KubeEdge Architecture

```
KubeEdge Cloud Side
├── CloudCore
│   ├── API Server (REST)
│   ├── Cloud Hub (WebSocket/QUIC)
│   └── Device Manager
│       ├── Device controller
│       ├── Twin controller
│       └── Mapper
├── MQTT Broker
│   └── Topic subscriptions
└── Database
    ├── Device metadata
    └── Twin state

KubeEdge Edge Side
├── EdgeCore
│   ├── Edge Hub (cloud connection)
│   ├── Device Twin (local state)
│   ├── Mapper (device integration)
│   └── EventBus (internal messaging)
└── Applications
    ├── ROS 2 nodes
    ├── Sensor drivers
    └── Actuator controllers
```

### 4. ROS 2 Integration

```
ROS 2 Deployment
├── DDS Middleware (FastDDS)
│   ├── Discovery: FastDDS Discovery Server (centralized, port 11811)
│   ├── Domain ID configuration
│   └── Data serialization
├── ROS 2 Nodes (Containers)
│   ├── Publisher nodes
│   ├── Subscriber nodes
│   ├── Service servers
│   └── Action servers
├── Service Discovery
│   ├── FastDDS Discovery Server coordination (required)
│   ├── ROS 2 node registration & peer discovery
│   └── Kubernetes DNS (*.pod.cluster.local)
└── Inter-Pod Communication
    ├── Direct UDP between registered peers
    ├── Cilium eBPF routing (transparent)
    └── Network policies enforced by Cilium
```

## Data Flow

### ROS 2 Message Flow

```
Publisher Pod (ros2-node-1)
    │
    ├─→ ROS 2 Publisher (topic: /sensor/camera)
    │
    ├─→ FastDDS Writer
    │
    ├─→ Query FastDDS Discovery Server (port 11811)
    │   ├─→ Register as writer
    │   └─→ Discover subscriber participants & endpoints
    │
    ├─→ Direct UDP to Subscriber Pod IP
    │
    ├─→ Cilium eBPF routing (transparent, enforces policies)
    │
    ├─→ Network Interface
    │
    └─→ Subscriber Pod (ros2-node-2)
        │
        ├─→ Network Interface
        │
        ├─→ Cilium eBPF ingress (validates policies)
        │
        ├─→ UDP Listener
        │
        ├─→ FastDDS Reader
        │
        └─→ ROS 2 Subscription (callback handler)
```

### Cloud-Edge Communication

```
Edge Node (Industrial PC)
    │
    ├─→ EdgeCore
    │
    ├─→ Local ROS 2 Nodes
    │
    └─→ Edge Hub
        │
        ├─→ Connect to CloudCore (WebSocket/QUIC)
        │   Port: 10000 (WebSocket), 10001 (QUIC)
        │
        ├─→ Authenticate with token
        │
        └─→ Establish secure tunnel
            │
            ├─→ Send sensor data
            │
            ├─→ Receive commands
            │
            └─→ Sync device state
                │
                └─→ Kubernetes API Server
                    │
                    ├─→ CloudCore processes
                    │
                    ├─→ ROS 2 K8s apps receive updates
                    │
                    └─→ Actions trigger edge nodes
```

## Scaling Architecture

### Horizontal Scaling

```
Minimum Configuration (Dev/Test)
├── Control Plane: 1 node
├── Worker Nodes: 1 node
├── Total: 2 nodes
└── Recommended: 2 GB RAM, 1 CPU per node

Standard Configuration (Production Small)
├── Control Plane: 3 nodes (HA)
├── Worker Nodes: 3-5 nodes
├── Total: 6-8 nodes
└── Recommended: 4 GB RAM, 2 CPU per node

Large Configuration (Production)
├── Control Plane: 5 nodes (HA + resilience)
├── Worker Nodes: 10-50 nodes
├── Total: 15-55 nodes
└── Recommended: 8 GB RAM, 4 CPU per node

Distributed Configuration (Multi-cluster)
├── Cloud Cluster: 50-100 nodes
├── Edge Clusters: 1-10 nodes each
├── Inter-cluster communication: KubeEdge federation
└── Data sync: etcd federation + RDS replication
```

### Vertical Scaling

```
Node Types by Workload
├── Control Plane
│   └── m6g.large (2 vCPU, 8 GB RAM)
├── ROS 2 Compute
│   ├── t4g.large (2 vCPU, 8 GB RAM) - General
│   ├── m6g.2xlarge (8 vCPU, 32 GB RAM) - Heavy compute
│   └── g4ad.xlarge (GPU) - Vision/ML
├── Edge Nodes
│   ├── ARM64 (Raspberry Pi, Jetson)
│   ├── x86_64 (Industrial PCs)
│   └── Custom hardware (with KubeEdge support)
└── RDS Database
    ├── Aurora PostgreSQL
    ├── db.r6g.xlarge (2 vCPU, 32 GB RAM) - Starter
    ├── db.r6g.4xlarge (16 vCPU, 128 GB RAM) - Production
    └── Auto-scaling read replicas
```

## High Availability Strategy

### Control Plane HA

```
Load Balancer (Route53)
    │
    ├─→ API Server #1 (10.0.0.10:6443)
    │   └─→ etcd node #1
    │
    ├─→ API Server #2 (10.0.0.11:6443)
    │   └─→ etcd node #2
    │
    └─→ API Server #3 (10.0.0.12:6443)
        └─→ etcd node #3
```

### Application HA

```
Service Load Balancer (Kubernetes)
    │
    ├─→ ROS 2 Pod #1 (replica 1)
    │
    ├─→ ROS 2 Pod #2 (replica 2)
    │
    └─→ ROS 2 Pod #3 (replica 3)
        └─→ PodDisruptionBudget (minAvailable: 2)
```

### Database HA

```
RDS Primary (Write)
    │
    ├─→ Synchronous replica (same AZ) - standby
    │
    └─→ Asynchronous replicas (different AZs) - read-only
        │
        ├─→ Replica #1 (for read scaling)
        │
        └─→ Replica #2 (for read scaling)
```

## Security Architecture

### Network Security

```
Internet
    │
    └─→ AWS Security Group (Ingress Rules)
        │
        ├─ Allow 443 (HTTPS)
        │
        └─ Allow 6443 (Kubernetes API)
            │
            └─→ VPC
                │
                ├─→ Public Subnets (NAT)
                │
                └─→ Private Subnets
                    │
                    ├─→ Control Plane (Restricted SG)
                    │
                    ├─→ Worker Nodes (Restricted SG)
                    │
                    ├─→ RDS (Restricted SG - Port 5432 only)
                    │
                    └─→ Network Policies (Cilium)
                        │
                        ├─ Pod-to-pod policies
                        │
                        ├─ Namespace isolation
                        │
                        └─ Ingress/Egress rules
```

### Data Security

```
Encryption in Transit
├── TLS 1.3 (API Server)
├── Cilium WireGuard (pod-to-pod)
├── HTTPS (web services)
└── QUIC (edge-cloud)

Encryption at Rest
├── etcd encryption (RawRC4)
├── RDS encryption (AWS KMS)
├── EBS encryption (AWS managed keys)
└── Secrets encryption (Kubernetes)

Authentication & Authorization
├── Service Account tokens
├── RBAC (Role-Based Access Control)
├── ABAC policies
├── Audit logging (CloudWatch)
└── Network policies (Cilium)
```

## Monitoring & Observability

```
Observability Stack
├── Metrics Collection
│   ├── Prometheus (scrape targets)
│   ├── Node exporter (system metrics)
│   ├── kube-state-metrics (K8s objects)
│   └── Custom app metrics (ROS 2)
├── Visualization
│   ├── Grafana (dashboards)
│   ├── Kubernetes Dashboard
│   └── CloudWatch
├── Logging
│   ├── Container logs (stdout/stderr)
│   ├── CloudWatch Logs
│   ├── ELK Stack (optional)
│   └── Fluent Bit forwarder
└── Tracing
    ├── Jaeger (distributed tracing)
    ├── Application instrumentation
    └── Request correlation
```

## Disaster Recovery

### Backup Strategy

```
Backup Frequency
├── etcd: Every 1 hour
├── RDS: Continuous + daily snapshots
├── Application configs: On deploy
└── Edge node configs: Synced to CloudCore

Backup Storage
├── S3 (redundancy)
├── RDS automated snapshots
├── Cross-region backups (optional)
└── 30-day retention policy

Recovery Procedure
├── Restore etcd: 15-30 minutes
├── Restore RDS: Point-in-time restore
├── Restore apps: From git repos
└── RTO: < 1 hour, RPO: < 5 minutes
```

## Cost Optimization

### Compute Cost Reduction

```
Strategy 1: SPOT Instances
├── Worker nodes on SPOT (20-80% savings)
├── Diversified instance types
└── Auto-replacement on interruption

Strategy 2: Reserved Capacity
├── Control plane: 1-year reserved
├── Baseline workers: 3-year reserved
└── Burst capacity: On-demand/SPOT

Strategy 3: Right-sizing
├── Monitor actual resource usage
├── Adjust node types quarterly
├── Use Karpenter for auto-scaling
└── Consolidate underutilized nodes

Total Monthly Savings: 40-60%
```

## Multi-Region/Cluster Architecture

```
Primary Region (us-west-2)
├── Production Cluster
│   ├── 50 worker nodes
│   ├── Multi-AZ RDS
│   └── Active workloads

Secondary Region (us-east-1)
├── Standby Cluster
│   ├── 10 worker nodes
│   └── Passive replication

Inter-Cluster Communication
├── Cluster Federation (optional)
├── Async replication (RDS)
├── Git-based config sync
└── Manual or automatic failover

Edge Locations
├── 5-10 edge clusters
├── Each 1-10 nodes
├── Connected via KubeEdge
└── Local data processing
```

## Upgrade Path

### Kubernetes Version Upgrades

```
Current: 1.28
├── 1.29 (March 2024)
├── 1.30 (April 2024)
├── 1.31 (May 2024)
└── Rolling upgrade: 1 node at a time

Strategy
├── Backup etcd
├── Drain nodes gracefully
├── Update control plane
├── Update kubelet on nodes
├── Verify cluster health
└── Rollback if needed (< 24 hours)
```

### Application Updates

```
GitOps Workflow
├── Develop locally
├── Test in staging cluster
├── Commit to main branch
├── ArgoCD auto-deploys
├── Canary deployment (10% → 50% → 100%)
└── Rollback on health check failures
```

## Performance Characteristics

### Latency

```
Control Plane Response
├── API request: < 100ms (99th percentile)
├── etcd write: < 10ms
└── Pod scheduling: < 5 seconds

ROS 2 Latency
├── Publisher to subscriber: < 10ms (local)
├── Cloud to edge: 50-200ms (network dependent)
└── DDS discovery: < 1 second

Database Latency
├── Write latency: < 5ms (primary)
├── Read latency: < 3ms (replicas)
└── Cross-AZ: < 50ms
```

### Throughput

```
API Server
├── Requests/sec: 10,000+ (depends on hardware)
├── Concurrent connections: 5,000+

Data Plane
├── Pod startup: 5-10 seconds
├── Network throughput: 25 Gbps (10G NICs)
├── Storage throughput: 16,000 IOPS (EBS)

ROS 2 Topics
├── Message rate: 10,000+ Hz (depends on size)
├── Bandwidth: Limited by network (1 Gbps default)
```

---

This architecture provides a solid foundation for deploying and managing containerized robotics applications with full cloud-edge integration, high availability, and automatic scaling capabilities.
