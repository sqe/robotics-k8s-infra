environment = "dev-001"
region = "us-west-2"
vpc_cidr = "10.0.0.0/16"
kubernetes_version = "1.33"
addons = {
    enable_aws_load_balancer_controller = true
    enable_metrics_server               = true
    enable_aws_cloudwatch_metrics       = true
    enable_external_dns                 = true
    }
backup_retention_period = 7
