# Module for creating vpc with subnets
# Provision:
# - VPC
# - Internet Gateway
# - XX Public Subnets
# - XX Private Subnets
# - XX NAT Gateways in Public subnets to give access to Internet from private Subnets
#
# Made by ALex Petrov May 2021

#-------------------------------------------------------------------------------

data "aws_availability_zones" "available" {}

# ---- VPC Creation-------------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-IGW"
  }
}

#------Public subnets---------------


resource "aws_subnet" "public_subnet" {
  count             = length(var.public_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.env} public subnet in ${data.aws_availability_zones.available.names[count.index]}"
  }
  map_public_ip_on_launch = true
}



resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.env} route for public subnets"
  }
}

resource "aws_route_table_association" "public_routes" {
  count          = length(aws_subnet.public_subnet[*].id)
  route_table_id = aws_route_table.public_route.id
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
}

#-----------------Private subnets-----------------------------------------

resource "aws_subnet" "private_subnet" {
  count             = length(var.private_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.env} private subnet in ${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_eip" "nat_ip" {
  count = length(var.private_cidrs)
  tags = {
    Name = "${var.env} IP addres for NGW in ${data.aws_availability_zones.available.names[count.index]} "
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = length(var.private_cidrs)
  allocation_id = aws_eip.nat_ip[count.index].id
  subnet_id     = aws_subnet.private_subnet[count.index].id
  tags = {
    Name = "${var.env} NGW in ${data.aws_availability_zones.available.names[count.index]}"
  }
}


resource "aws_route_table" "private_route" {
  count  = length(var.private_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw[count.index].id
  }
  tags = {
    Name = "${var.env} route to NGW in ${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table_association" "private_routes" {
  count          = length(aws_subnet.private_subnet[*].id)
  route_table_id = aws_route_table.private_route[count.index].id
  subnet_id      = element(aws_subnet.private_subnet[*].id, count.index)
}

#===================================================================================
