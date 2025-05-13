resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = var.tags.vpc
  }
}

resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = lookup(each.value, "az", null)
  map_public_ip_on_launch = true

  tags = {
    Name = each.key
  }
}
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_block
  availability_zone = lookup(each.value, "az", null)

  tags = {
    Name = each.key
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.tags.internet_gateway
  }
}

resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = var.tags.publicRT
  }
}
resource "aws_route_table" "privateRT" {
  vpc_id = aws_vpc.vpc.id

  # route {
  #   cidr_block = "10.0.0.0/16"
  # }

  tags = {
    Name = var.tags.privateRT
  }
}

resource "aws_route_table_association" "publicRT_association" {
  for_each       = var.public_subnets
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.publicRT.id
}

resource "aws_route_table_association" "privateRT_association" {
  for_each       = var.private_subnets
  subnet_id      = aws_subnet.private_subnets[each.key].id
  route_table_id = aws_route_table.privateRT.id
}