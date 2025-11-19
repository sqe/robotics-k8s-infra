resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name        = "${var.environment}-vpc"
    environment = var.environment
  }
}

resource "aws_subnet" "subnet_public_a" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnet_a_cidr_block)
  cidr_block              = element(var.public_subnet_a_cidr_block, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet"
    environment = var.environment
  }
}


resource "aws_subnet" "subnet_private_a" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnet_a_cidr_block)
  cidr_block              = element(var.private_subnet_a_cidr_block, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-private-subnet"
    environment = var.environment
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_eip" "eip_nat_a" {
  # vpc        = true
  depends_on = ["aws_internet_gateway.internet_gateway"]

  tags = {
    environment = var.environment
  }
}

resource "aws_eip" "eip_nat_b" {
  # vpc        = true
  depends_on = ["aws_internet_gateway.internet_gateway"]

  tags = {
    environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.eip_nat_a.id
  subnet_id     = element(aws_subnet.subnet_public_a.*.id, 0)
  depends_on    = ["aws_internet_gateway.internet_gateway"]

  tags = {
    environment = var.environment
  }
}

resource "aws_route_table" "private_route_table_a" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    environment = var.environment
  }
}

resource "aws_route" "private_route_a" {
  route_table_id         = aws_route_table.private_route_table_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id

}

# Associate subnet public subnet a to public route table
resource "aws_route_table_association" "subnet_public_a_association" {
  count          = length(var.public_subnet_a_cidr_block)
  subnet_id      = element(aws_subnet.subnet_public_a.*.id, count.index)
  route_table_id = aws_vpc.vpc.main_route_table_id
}

# Associate subnet private subnet a to private route table
resource "aws_route_table_association" "subnet_private_a_association" {
  count          = length(var.private_subnet_a_cidr_block)
  subnet_id      = element(aws_subnet.subnet_private_a.*.id, count.index)
  route_table_id = aws_route_table.private_route_table_a.id

}

resource "aws_security_group" "internal" {
  name        = "Internal"
  description = "Internal security group for all VPC resources"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}