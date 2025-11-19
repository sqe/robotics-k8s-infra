# Terraform Infrastructure as Code

Comprehensive infrastructure automation for cloud-native applications with integrated DevOps capabilities. This repository demonstrates production-grade Terraform patterns for managing containerized workloads, databases, networking, and simulation environments.

## Repository Structure

```
infra/
├── environments/          # Environment-specific configurations
│   └── development/
│       └── dev-001/       # Development environment
│           ├── main.tf
│           ├── variables.tf
│           └── terraform.tfvars
├── modules/               # Reusable Terraform modules
│   ├── docker-simulator/  # Docker container management for ROS 2 simulator
│   ├── rds-aurora-pg/     # AWS Aurora PostgreSQL database
│   └── vpc/               # VPC networking infrastructure
└── README.md             # This file
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Development Environment                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────┐         ┌──────────────────────┐      │
│  │   EKS Cluster        │         │  Docker Simulator    │      │
│  │  (Kubernetes)        │◄────────┤  (ROS 2 Environment) │      │
│  │                      │         │                      │      │
│  │  • ArgoCD            │         │  • VNC Access:5900   │      │
│  │  • Helm Charts       │         │  • Network: Isolated │      │
│  │  • Ingress           │         │  • Volumes: Config   │      │
│  │  • Load Balancer     │         └──────────────────────┘      │
│  └──────────────────────┘                                        │
│         ▲                                                         │
│         │                                                         │
│  ┌──────┴──────────────────────┐                                 │
│  │                              │                                │
│  │    VPC & Networking          │                                │
│  │  ┌──────────────────────┐    │                                │
│  │  │  • Private Subnets   │    │                                │
│  │  │  • Public Subnets    │    │                                │
│  │  │  • NAT Gateway       │    │                                │
│  │  │  • Route53           │    │                                │
│  │  │  • Security Groups   │    │                                │
│  │  └──────────────────────┘    │                                │
│  └──────────────────────────────┘                                │
│         │                                                         │
│         │                                                         │
│  ┌──────▼──────────────────────┐                                 │
│  │                              │                                │
│  │  Aurora PostgreSQL           │                                │
│  │  • High Availability         │                                │
│  │  • Automated Backups         │                                │
│  │  • Read Replicas             │                                │
│  │  • Security Groups           │                                │
│  │                              │                                │
│  └──────────────────────────────┘                                │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

### 1. Docker Simulator Module

**Location**: `./modules/docker-simulator/`

Manages Docker resources for local development and simulation environments. Ideal for spinning up ROS 2 simulators or utility containers.

**Key Features**:
- Pulls and manages Docker images
- Creates isolated Docker networks
- Configures port mappings and volume mounts
- Sets resource constraints (CPU, memory)
- Manages environment variables
- Automatic container restart policies

**Resources Created**:
- Docker Image (ROS 2)
- Docker Network
- Docker Container

**Use Cases**:
- Local robotics simulation environments
- Development utility containers
- Quick-start testing environments
- VNC-based visualization access

[Full Documentation](./modules/docker-simulator/README.md)

**Example Usage**:
```hcl
module "docker_simulator" {
  source = "./modules/docker-simulator"

  container_name = "dev-ros2-simulator"
  ros2_image     = "osrf/ros:humble-desktop"
  
  port_mappings = [{
    internal = 5900
    external = 5900
  }]
  
  memory_mb = 2048
}
```

---

### 2. RDS Aurora PostgreSQL Module

**Location**: `./modules/rds-aurora-pg/`

Provisions a fully-managed Aurora PostgreSQL cluster with high availability and automated backup capabilities.

**Key Features**:
- Multi-AZ Aurora PostgreSQL cluster
- Automated daily backups
- Configurable retention period
- Security group integration
- Parameter group management
- Enhanced monitoring

**Resources Created**:
- Aurora DB Cluster
- Aurora DB Cluster Instances
- DB Subnet Group
- DB Parameter Group
- Enhanced Monitoring IAM Role

**Use Cases**:
- Production relational databases
- Application data persistence
- High-availability requirements
- Backup and disaster recovery

**Inputs**:
- `environment` - Environment name
- `vpc_id` - VPC for database
- `subnet_ids` - Private subnets for database
- `backup_retention_period` - Days to retain backups
- `rds_security_group_id` - Security group for access

[Full Documentation](./modules/rds-aurora-pg/README.md)

**Example Usage**:
```hcl
module "aurora_postgresql" {
  source = "./modules/rds-aurora-pg"

  environment            = "dev"
  vpc_id                = aws_vpc.main.id
  subnet_ids            = aws_subnet.private[*].id
  backup_retention_period = 7
  rds_security_group_id = aws_security_group.rds.id
}
```

---

### 3. VPC Module

**Location**: `./modules/vpc/` (Terraform AWS Modules)

Manages VPC networking infrastructure including subnets, NAT gateways, and route tables.

**Key Features**:
- Multi-AZ public and private subnets
- NAT gateway for private subnet egress
- VPC flow logs
- DNS configuration
- Security group templates
- Kubernetes-optimized tagging

**Resources Created**:
- VPC
- Public and Private Subnets
- Internet Gateway
- NAT Gateway
- Route Tables and Routes
- Network ACLs

[Full Documentation](./modules/vpc/README.md)

---

## Environment: Development (dev-001)

**Location**: `./environments/development/dev-001/`

Complete development environment configuration integrating all modules.

### Providers Configured

| Provider | Purpose | Version |
|----------|---------|---------|
| **AWS** | Primary cloud infrastructure | ~> 5.0 |
| **AWS (Domain Account)** | Cross-account Route53 management | ~> 5.0 |
| **Kubernetes** | EKS cluster management | ~> 2.20 |
| **Helm** | Kubernetes package management | ~> 2.10 |
| **Docker** | Container management | ~> 3.0 |

### Infrastructure Components

#### 1. EKS Kubernetes Cluster
- **Node Group**: Graviton-based ARM64 instances (m6g.large)
- **Capacity Type**: SPOT (cost-optimized)
- **Node Count**: 1-2 nodes
- **Addons**:
  - CoreDNS
  - kube-proxy
  - VPC CNI with prefix delegation
  - ACM Certificate Management
  - External DNS
  - Ingress NGINX
  - ArgoCD (GitOps)
  - Kube Prometheus Stack

#### 2. VPC & Networking
- **CIDR**: Configurable (default: 10.0.0.0/16)
- **AZs**: 3 availability zones
- **NAT Gateway**: Single NAT for all private subnets
- **Route53**: 
  - Hosted zone: dev.oss-iac.com
  - Cross-account delegation via domain_account provider

#### 3. Aurora PostgreSQL Database
- **Engine**: PostgreSQL (Aurora)
- **Backup**: Configurable retention period
- **Security**: Private subnets, EKS cluster access
- **Monitoring**: CloudWatch integration

#### 4. Docker Simulator
- **Image**: ROS 2 Humble Desktop
- **Network**: Isolated Docker network
- **Ports**: VNC access on 5900
- **Volumes**: Configuration mounting support
- **Resources**: 1 CPU, 2GB RAM

### AWS IAM Roles & Policies

The configuration includes several IAM policies for workload access:

1. **Node ACM Policy**: EKS nodes can query ACM certificates
2. **Node ELB Policy**: EKS nodes can manage load balancers
3. **External DNS Cross-Account**: DNS management across accounts

### DNS Configuration

```
oss-iac.com (parent domain in separate account)
    └── dev.oss-iac.com (NS records delegated)
        ├── app.dev.oss-iac.com (ACM certificate)
        ├── *.dev.oss-iac.com (External DNS managed)
```

## Getting Started

### Prerequisites

1. **Terraform**: >= 1.0
   ```bash
   terraform version
   ```

2. **AWS CLI**: Configured with appropriate credentials
   ```bash
   aws configure
   export AWS_PROFILE=oss-iac-iam
   ```

3. **kubectl**: For Kubernetes cluster access
   ```bash
   kubectl version --client
   ```

4. **Helm**: For package management
   ```bash
   helm version
   ```

5. **Docker**: Running daemon (for simulator module)
   ```bash
   docker --version
   ```

### Environment Setup

1. **Clone and navigate**:
   ```bash
   cd infra/environments/development/dev-001
   ```

2. **Review variables**:
   ```bash
   cat variables.tf
   cat terraform.tfvars
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Validate configuration**:
   ```bash
   terraform validate
   terraform plan
   ```

5. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

6. **Access EKS cluster**:
   ```bash
   aws eks update-kubeconfig --name dev --region us-west-2
   kubectl get nodes
   kubectl get pods -A
   ```

## Outputs

After successful `terraform apply`, access infrastructure details:

### EKS & Kubernetes
```bash
terraform output eks_cluster_name
terraform output eks_cluster_endpoint
terraform output eks_cluster_security_group_id
```

### Database
```bash
terraform output database_password  # Sensitive output
```

### Docker Simulator
```bash
terraform output docker_container_id
terraform output docker_container_name
terraform output docker_vnc_access
```

### DNS & Networking
```bash
terraform output nameservers
terraform output zone_id
```

## Common Operations

### Scaling EKS Nodes

Modify `environments/development/dev-001/main.tf`:
```hcl
eks_managed_node_groups = {
  graviton = {
    min_size     = 1
    max_size     = 5      # Increase max capacity
    desired_size = 2      # Scale to 2 nodes
    # ...
  }
}
```

Then apply:
```bash
terraform apply
```

### Accessing Databases

1. **Get connection string**:
   ```bash
   terraform output database_password
   ```

2. **Connect via kubectl port-forward** (if needed):
   ```bash
   kubectl port-forward -n default svc/my-app 5432:5432
   ```

3. **Query database**:
   ```bash
   psql -h <aurora-endpoint> -U admin -d postgres
   ```

### Managing Docker Simulator

1. **Start simulator**:
   ```bash
   terraform apply -target=module.docker_simulator
   ```

2. **Access VNC**:
   ```bash
   # VNC client: localhost:5900
   ```

3. **View logs**:
   ```bash
   docker logs ros2-tf-simulator
   ```

4. **Stop simulator**:
   ```bash
   terraform destroy -target=module.docker_simulator
   ```

## State Management

### Local State (Development)
```bash
# State file
ls -la terraform.tfstate*

# Backup state
cp terraform.tfstate terraform.tfstate.backup
```

### Remote State (Recommended for Production)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Monitoring & Logging

### CloudWatch
- EKS control plane logs
- Application logs via CloudWatch agent
- RDS enhanced monitoring

### Prometheus & Grafana
- Kube Prometheus Stack (enabled in addons)
- Custom metrics and dashboards
- Alert rules for cluster health

### VPC Flow Logs
- Network traffic monitoring
- Troubleshooting network issues

## Troubleshooting

### EKS Cluster Issues

1. **Check cluster health**:
   ```bash
   aws eks describe-cluster --name dev --region us-west-2
   ```

2. **View cluster events**:
   ```bash
   kubectl get events -A
   ```

3. **Validate addons**:
   ```bash
   kubectl get pods -n kube-system
   kubectl get pods -n argocd
   ```

### Database Connection Issues

1. **Check RDS security group**:
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

2. **Verify subnet configuration**:
   ```bash
   terraform show -json | jq '.resources[] | select(.type=="aws_db_subnet_group")'
   ```

### Docker Simulator Issues

1. **Check Docker daemon**:
   ```bash
   docker ps
   docker logs ros2-tf-simulator
   ```

2. **Verify port access**:
   ```bash
   netstat -an | grep 5900
   ```

## Cleanup

### Destroy All Resources
```bash
terraform destroy
```

### Destroy Specific Module
```bash
terraform destroy -target=module.docker_simulator
terraform destroy -target=module.aurora_postgresql
```

### Preserve RDS (Snapshot First)
```bash
# Create snapshot
aws rds create-db-cluster-snapshot --db-cluster-identifier dev

# Then destroy
terraform destroy -target=module.aurora_postgresql
```

## Best Practices

### Terraform

1. ✅ **Use remote state** for team environments
2. ✅ **Implement state locking** with DynamoDB
3. ✅ **Use workspaces** for environment separation
4. ✅ **Apply resource tagging** for cost tracking
5. ✅ **Review plans** before applying

### AWS Security

1. ✅ **Use IAM roles** for service authentication
2. ✅ **Enable encryption** for data at rest and in transit
3. ✅ **Implement network segmentation** with security groups
4. ✅ **Enable logging** and monitoring
5. ✅ **Rotate credentials** regularly

### Kubernetes

1. ✅ **Use RBAC** for access control
2. ✅ **Implement network policies** for pod communication
3. ✅ **Use resource requests/limits** for stability
4. ✅ **Enable pod security policies**
5. ✅ **Use GitOps** for deployments (ArgoCD)

## Documentation References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Architecture Center](https://aws.amazon.com/architecture/)

## Contributing

When adding new modules:

1. Create module directory under `./modules/`
2. Include `main.tf`, `variables.tf`, `outputs.tf`, and `README.md`
3. Use consistent naming conventions
4. Document all variables and outputs
5. Include usage examples in README
6. Add module integration to environment

## Support & Issues

- Review Terraform logs: `TF_LOG=DEBUG terraform apply`
- Check AWS credentials: `aws sts get-caller-identity`
- Validate syntax: `terraform fmt -recursive`
- Lint code: `terraform validate`

## License

[Your License Here]

---

**Last Updated**: November 2025
**Terraform Version**: >= 1.0
**Provider Versions**: See individual module README files
