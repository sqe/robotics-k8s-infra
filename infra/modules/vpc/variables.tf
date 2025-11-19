variable "vpc_cidr_block" {

  description = "VPC CIDR block (i.e. 0.0.0.0/0)"
}

variable "public_subnet_a_cidr_block" {
  type        = list(any)
  description = "Public Subnet A CIDR block (i.e. 0.0.0.0/0)"
}

variable "private_subnet_a_cidr_block" {
  type        = list(any)
  description = "Private Subnet A CIDR block (i.e. 0.0.0.0/0)"
}

variable "environment" {
  description = "Either integration, staging or production"
}

variable "availability_zones" {
  type        = list(any)
  description = "AZ in which all the resources will be deployed"
}