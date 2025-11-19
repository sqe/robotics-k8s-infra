variable "environment" {
  type        = string
  description = "The environment to use for the VPC."
}

variable "region" {
  type        = string
  description = "The AWS region to use."
}

variable "vpc_id" {
  type        = string
  description = "variable to pass vpc_id of the environment vpc"

}

# [TODO] - make rds configs overridable
# variable "rds-aurora_psql_engine" {
#     type = string
#     description = "rds aurora engine for psql"
# }

# variable "rds-aurora_psql_engine_version" {
#     type = string
#     description = "rds aurora engine for psql"
# }

# variable "instance_class" {
#     type = string
#     description = "Data Base instance class"
# }

# variable "db_subnet_group_name" {
#     description = "variable to pass db_subnet_group_name "
# }

variable "rds_security_group_id" {
  description = "variable to pass rds_security_group_id"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Variable to pass subnet id for db"
}

variable "backup_retention_period" {
  type = number
  
}