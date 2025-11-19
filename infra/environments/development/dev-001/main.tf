provider "aws" {
  region = "us-west-2"
  profile = "oss-iac-iam"
  shared_credentials_files = ["~/.aws/credentials"]

  default_tags {
    tags = {
      Owner = "oss-iac Engineering"
      Project = "Cloud Infrastructure"
    }
  }
  assume_role {
    session_name = "Terraform"
    role_arn    = "arn:aws:iam::869935068873:role/developers"
  }
}
# Add domain account provider
provider "aws" {
  alias  = "domain_account"
  region = "us-west-2"
  profile = "oss-iac-iam"
  shared_credentials_files = ["~/.aws/credentials"]

  default_tags {
    tags = {
      Owner = "oss-iac Engineering"
      Project = "Cloud Infrastructure"
    }
  }
  assume_role {
    session_name = "Terraform"
    role_arn = "arn:aws:iam::557690619662:role/route53"
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

################################################################################
# Docker Provider
################################################################################
# Manages Docker resources for local development environments
# Requires Docker daemon to be running on the host where Terraform is executed
provider "docker" {
  # Configuration will use Docker socket from the host
  # On Linux/Mac: unix:///var/run/docker.sock (default)
  # On Windows: npipe:////./pipe/docker_engine (set via DOCKER_HOST env var)
}

locals {
  name   = var.environment
  region = var.region
  domain_name = "dev.oss-iac.com"  # Adjust domain name as needed

  cluster_version = var.kubernetes_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)  // Take 3 AZs

  gitops_addons_url      = "${var.gitops_addons_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath = var.gitops_addons_basepath
  gitops_addons_path     = var.gitops_addons_path
  gitops_addons_revision = var.gitops_addons_revision

  gitops_workload_url      = "${var.gitops_workload_org}/${var.gitops_workload_repo}"
  gitops_workload_basepath = var.gitops_workload_basepath
  gitops_workload_path     = var.gitops_workload_path
  gitops_workload_revision = var.gitops_workload_revision

  aws_addons = {
    enable_cert_manager                          = try(var.addons.enable_cert_manager, false)
    enable_aws_efs_csi_driver                    = try(var.addons.enable_aws_efs_csi_driver, false)
    enable_aws_fsx_csi_driver                    = try(var.addons.enable_aws_fsx_csi_driver, false)
    enable_aws_cloudwatch_metrics                = try(var.addons.enable_aws_cloudwatch_metrics, true)
    enable_aws_privateca_issuer                  = try(var.addons.enable_aws_privateca_issuer, false)
    enable_cluster_autoscaler                    = try(var.addons.enable_cluster_autoscaler, false)
    enable_external_dns                          = try(var.addons.enable_external_dns, true)
    enable_external_secrets                      = try(var.addons.enable_external_secrets, false)
    enable_aws_load_balancer_controller          = try(var.addons.enable_aws_load_balancer_controller, true)
    enable_fargate_fluentbit                     = try(var.addons.enable_fargate_fluentbit, false)
    enable_aws_for_fluentbit                     = try(var.addons.enable_aws_for_fluentbit, false)
    enable_aws_node_termination_handler          = try(var.addons.enable_aws_node_termination_handler, false)
    enable_karpenter                             = try(var.addons.enable_karpenter, false)
    enable_velero                                = try(var.addons.enable_velero, false)
    enable_aws_gateway_api_controller            = try(var.addons.enable_aws_gateway_api_controller, false)
    enable_aws_ebs_csi_resources                 = try(var.addons.enable_aws_ebs_csi_resources, false)
    enable_aws_secrets_store_csi_driver_provider = try(var.addons.enable_aws_secrets_store_csi_driver_provider, false)
    enable_ack_apigatewayv2                      = try(var.addons.enable_ack_apigatewayv2, false)
    enable_ack_dynamodb                          = try(var.addons.enable_ack_dynamodb, false)
    enable_ack_s3                                = try(var.addons.enable_ack_s3, false)
    enable_ack_rds                               = try(var.addons.enable_ack_rds, false)
    enable_ack_prometheusservice                 = try(var.addons.enable_ack_prometheusservice, false)
    enable_ack_emrcontainers                     = try(var.addons.enable_ack_emrcontainers, false)
    enable_ack_sfn                               = try(var.addons.enable_ack_sfn, false)
    enable_ack_eventbridge                       = try(var.addons.enable_ack_eventbridge, false)
  }
  oss_addons = {
    enable_argocd                          = try(var.addons.enable_argocd, true)
    enable_argo_rollouts                   = try(var.addons.enable_argo_rollouts, false)
    enable_argo_events                     = try(var.addons.enable_argo_events, false)
    enable_argo_workflows                  = try(var.addons.enable_argo_workflows, false)
    enable_cluster_proportional_autoscaler = try(var.addons.enable_cluster_proportional_autoscaler, false)
    enable_gatekeeper                      = try(var.addons.enable_gatekeeper, false)
    enable_gpu_operator                    = try(var.addons.enable_gpu_operator, false)
    enable_ingress_nginx                   = try(var.addons.enable_ingress_nginx, true)
    enable_kyverno                         = try(var.addons.enable_kyverno, false)
    enable_kube_prometheus_stack           = try(var.addons.enable_kube_prometheus_stack, true)
    enable_metrics_server                  = try(var.addons.enable_metrics_server, false)
    enable_prometheus_adapter              = try(var.addons.enable_prometheus_adapter, false)
    enable_secrets_store_csi_driver        = try(var.addons.enable_secrets_store_csi_driver, false)
    enable_vpa                             = try(var.addons.enable_vpa, false)
  }
  addons = merge(
    local.aws_addons,
    local.oss_addons,
    { kubernetes_version = local.cluster_version },
    { aws_cluster_name = module.eks.cluster_name }
  )

  addons_metadata = merge(
    module.eks_blueprints_addons.gitops_metadata,
    {
      aws_cluster_name = module.eks.cluster_name
      aws_region       = local.region
      aws_account_id   = data.aws_caller_identity.current.account_id
      aws_vpc_id       = module.vpc.vpc_id
    },
    {
      addons_repo_url      = local.gitops_addons_url
      addons_repo_basepath = local.gitops_addons_basepath
      addons_repo_path     = local.gitops_addons_path
      addons_repo_revision = local.gitops_addons_revision
    },
    {
      workload_repo_url      = local.gitops_workload_url
      workload_repo_basepath = local.gitops_workload_basepath
      workload_repo_path     = local.gitops_workload_path
      workload_repo_revision = local.gitops_workload_revision
    }
  )

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  source = "github.com/gitops-bridge-dev/gitops-bridge-argocd-bootstrap-terraform?ref=v2.0.0"

  cluster = {
    metadata = local.addons_metadata
    addons   = local.addons
  }
}

################################################################################
# EKS Blueprints Addons
################################################################################
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.22"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Using GitOps Bridge
  create_kubernetes_resources = false

  # EKS Blueprints Addons
  enable_cert_manager                 = local.aws_addons.enable_cert_manager
  enable_aws_efs_csi_driver           = local.aws_addons.enable_aws_efs_csi_driver
  enable_aws_fsx_csi_driver           = local.aws_addons.enable_aws_fsx_csi_driver
  enable_aws_cloudwatch_metrics       = local.aws_addons.enable_aws_cloudwatch_metrics
  enable_aws_privateca_issuer         = local.aws_addons.enable_aws_privateca_issuer
  enable_cluster_autoscaler           = local.aws_addons.enable_cluster_autoscaler
  enable_external_dns                 = local.aws_addons.enable_external_dns
  enable_external_secrets             = local.aws_addons.enable_external_secrets
  enable_aws_load_balancer_controller = local.aws_addons.enable_aws_load_balancer_controller
  enable_fargate_fluentbit            = local.aws_addons.enable_fargate_fluentbit
  enable_aws_for_fluentbit            = local.aws_addons.enable_aws_for_fluentbit
  enable_aws_node_termination_handler = local.aws_addons.enable_aws_node_termination_handler
  enable_karpenter                    = local.aws_addons.enable_karpenter
  enable_velero                       = local.aws_addons.enable_velero
  enable_aws_gateway_api_controller   = local.aws_addons.enable_aws_gateway_api_controller

  tags = local.tags
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {

    graviton = {
      instance_types = ["m6g.large"]  # Graviton-based instances
      ami_type       = "AL2023_ARM_64_STANDARD"  # Amazon Linux 2023 (AL2023) for ARM64 architecture
      min_size     = 1
      max_size     = 2
      desired_size = 1

      capacity_type = "SPOT"  # Use SPOT for cost savings or "ON_DEMAND" for production

      labels = {
        Architecture = "arm64"
        Instance    = "graviton"
      }

      # taints = {
      #   dedicated = {
      #     key    = "cpu-architecture"
      #     value  = "arm64"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }
  }
  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      # See README for further details
      before_compute = true
      most_recent    = true # To ensure access to the latest settings provided
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }
  tags = local.tags
}

resource "aws_iam_role_policy" "node_acm_policy" {
  name = "node-acm-policy"
  role = module.eks.eks_managed_node_groups["graviton"].iam_role_name
  depends_on = [ module.eks ]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:ListCertificates",
          "acm:DescribeCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "node_elb_policy" {
  name = "node-elb-policy"
  role = module.eks.eks_managed_node_groups["graviton"].iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
resource "aws_acm_certificate" "rich_app" {
  domain_name       = "app.dev.oss-iac.com"
  validation_method = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "rich_app_validation" {
  for_each = {
    for dvo in aws_acm_certificate.rich_app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.dev.zone_id
}

resource "aws_acm_certificate_validation" "rich_app" {
  certificate_arn         = aws_acm_certificate.rich_app.arn
  validation_record_fqdns = [for record in aws_route53_record.rich_app_validation : record.fqdn]
}


resource "kubernetes_config_map_v1_data" "aws_auth_users" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = "arn:aws:iam::869935068873:role/developers"
        username = "developers"
        groups   = ["system:masters"]
      }
    ])
  }

  force = true
}

################################################################################
# Supporting Resources
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# Aurora PostgreSQL
################################################################################
module "aurora_postgresql" {
  source = "../../../modules/rds-aurora-pg"

  # Required attributes
  environment = local.name
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnets
  region = var.region
  backup_retention_period = var.backup_retention_period
  rds_security_group_id = aws_security_group.rds.id
}

output "database_password" {
  description = "The master password for the Aurora PostgreSQL database"
  value       = module.aurora_postgresql.master_password
  sensitive   = true
}
# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.name}-rds"
  description = "Security group for RDS Aurora PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  tags = local.tags
}

# Add this policy to the external-dns IAM role
resource "aws_iam_role_policy" "external_dns_cross_account" {
  name = "external-dns-cross-account"
  role = module.external_dns_irsa.iam_role_name
  depends_on = [ module.eks ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/ZSLSKJMSECSWOEYG5809"

        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = ["*"]
      }
    ]
  })
}


################################################################################
# External DNS IAM Role
################################################################################
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                  = "${local.name}-external-dns"
  attach_external_dns_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = local.tags
}

################################################################################
# Docker Simulator Module
################################################################################
module "docker_simulator" {
  source = "../../../modules/docker-simulator"

  # Container and network naming
  container_name = "${local.name}-ros2-simulator"
  network_name   = "${local.name}-ros2-network"

  # Docker image configuration
  ros2_image           = "osrf/ros:humble-desktop"
  keep_image_locally   = true

  # Port mappings for VNC and visualization
  port_mappings = [
    {
      internal = 5900
      external = 5900
    }
  ]

  # Volume mounts for simulation configuration
  volume_mounts = [
    {
      host_path      = abspath("${path.module}/../../config/sim_params.yaml")
      container_path = "/root/sim_config/params.yaml"
    }
  ]

  # Resource constraints
  cpu_shares = 1024
  memory_mb  = 2048

  # Environment variables
  environment_variables = [
    "ROS_DOMAIN_ID=0",
    "ROS_LOCALHOST_ONLY=0"
  ]

  # Labels for tracking
  labels = merge(
    local.tags,
    {
      "service"     = "ros2-simulator"
      "environment" = local.name
    }
  )
}

# Create the dev subdomain zone in the current account
resource "aws_route53_zone" "dev" {
  name = "dev.oss-iac.com"
}

# Create NS record in the parent domain using the main provider (same account as hosted zone)
resource "aws_route53_record" "dev_ns" {
  provider = aws.domain_account
  zone_id  = "ZGQWGAPWLGSAWPUGYH49" # Need the hosted zone ID of oss-iac.com
  name     = "dev.oss-iac.com"
  type     = "NS"
  ttl      = "300"
  records  = aws_route53_zone.dev.name_servers
}

# Instead of creating the A record here, we'll let external-dns create it
# The A record will be created automatically when the ingress is created
# Remove the aws_route53_record "rich_app" resource

output "nameservers" {
  value = aws_route53_zone.dev.name_servers
}

output "zone_id" {
  value = aws_route53_zone.dev.zone_id
  description = "The Zone ID of the dev subdomain"
}

################################################################################
# Docker Simulator Outputs
################################################################################
output "docker_container_id" {
  value       = module.docker_simulator.container_id
  description = "ID of the ROS 2 simulator container"
}

output "docker_container_name" {
  value       = module.docker_simulator.container_name
  description = "Name of the ROS 2 simulator container"
}

output "docker_network_id" {
  value       = module.docker_simulator.network_id
  description = "ID of the ROS 2 simulator network"
}

output "docker_image_id" {
  value       = module.docker_simulator.image_id
  description = "ID of the ROS 2 Docker image"
}

output "docker_vnc_access" {
  value       = "localhost:5900"
  description = "VNC access point for the ROS 2 simulator visualization"
}
################################################################################

# This configuration:

# Integrates with your existing EKS blueprints setup
# Creates a Route53 hosted zone
# Enables external-dns and AWS Load Balancer Controller
# Sets up IAM roles for external-dns service account
# After applying this, you can use annotations in your Kubernetes ingress resources like:

# annotations:
#   kubernetes.io/ingress.class: nginx
#   external-dns.alpha.kubernetes.io/hostname: myapp.dev.oss-iac.com
