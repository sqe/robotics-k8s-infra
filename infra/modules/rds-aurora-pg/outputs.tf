
output "db_subnet_group_name" {
  value = aws_db_subnet_group.default.name
}

# output "master_password" {
#   description = "The master password for the database"
#   value       = module.rds_aurora_pg.cluster_master_password
#   sensitive   = true
# }

output "master_user_secret" {
  description = "The generated secret for the master user"
  value       = module.rds_aurora_pg.cluster_master_user_secret
}

output "cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = module.rds_aurora_pg.cluster_endpoint
}
output "master_password" {
  description = "The master password for the database"
  value       = random_password.master_password.result
  sensitive   = true
}
