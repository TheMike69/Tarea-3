terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# La VPC es regional; las subnets se distribuyen entre dos zonas.
locals {
  zones = {
    "us-east-1a" = {
      public_cidr  = "10.0.1.0/24"
      private_cidr = "10.0.11.0/24"
    }
    "us-east-1b" = {
      public_cidr  = "10.0.2.0/24"
      private_cidr = "10.0.12.0/24"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tarea3-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = local.zones

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.public_cidr
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "tarea3-subnet-publica-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.zones

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.private_cidr
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "tarea3-subnet-privada-${each.key}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tarea3-internet-gateway"
  }
}

# Cada NAT Gateway tiene una IP elastica y reside en una subnet publica.
resource "aws_eip" "nat" {
  for_each = local.zones
  domain   = "vpc"

  tags = {
    Name = "tarea3-eip-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "main" {
  for_each = local.zones

  allocation_id     = aws_eip.nat[each.key].id
  subnet_id         = aws_subnet.public[each.key].id
  connectivity_type = "public"

  tags = {
    Name = "tarea3-nat-gateway-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Ambas subnets publicas salen a Internet mediante la Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "tarea3-rutas-publicas"
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.zones

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# Cada subnet privada sale mediante el NAT Gateway de su misma zona.
resource "aws_route_table" "private" {
  for_each = local.zones

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = {
    Name = "tarea3-rutas-privadas-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.zones

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
