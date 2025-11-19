resource "aws_db_subnet_group" "default" {
  name        = "${var.environment}-db-subnet-group"
  description = "Database subnet group for ${var.environment}"

  subnet_ids = var.subnet_ids
}

# Random password generation
resource "random_password" "master_password" {
  length           = 16
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


module "rds_aurora_pg" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "8.3.1"

  name           = "${var.environment}-aurora-pg"
  engine         = "aurora-postgresql"
  engine_version = "14.15"
  instance_class = "db.r5.large"
  instances = {
    one = {}
  }
  

  autoscaling_enabled = false
  #   autoscaling_min_capacity = 1
  #   autoscaling_max_capacity = 2

  vpc_id = var.vpc_id
  # Disable creation of subnet group - provide a subnet group
  db_subnet_group_name   = aws_db_subnet_group.default.id
  create_db_subnet_group = false

  # Disable creation of security group - provide a security group
  create_security_group = true
  #   vpc_security_group_ids    = module.vpc.rds_security_group_id
  master_username                 = "root"
  master_password                 = random_password.master_password.result
  storage_encrypted               = true
  apply_immediately               = true
  monitoring_interval             = 10
  manage_master_user_password     = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  skip_final_snapshot             = true
  backup_retention_period         = var.backup_retention_period
  deletion_protection             = false
  database_name                   = "richapp"
  publicly_accessible = true
  enable_http_endpoint = true
  tags = {
    environment = var.environment
    terraform   = "true"
  }

}

# Store the password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "aurora_master_password" {
  name = "${var.environment}-aurora-master-password"
  # tags = "${var.environment}"
}

resource "aws_secretsmanager_secret_version" "aurora_master_password" {
  secret_id = aws_secretsmanager_secret.aurora_master_password.id
  secret_string = sensitive(jsonencode({
    username = "root"
    password = random_password.master_password.result
  }))
}
