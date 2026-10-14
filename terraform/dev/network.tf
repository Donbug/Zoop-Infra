# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-a"
    Tier = "public"
  }
}

# Private App Subnet - AZ A
resource "aws_subnet" "private_app_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-app-a"
    Tier = "private-app"
  }
}

# Private App Subnet - AZ C
resource "aws_subnet" "private_app_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-app-c"
    Tier = "private-app"
  }
}

# Private DB Subnet - AZ A
resource "aws_subnet" "private_db_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-db-a"
    Tier = "private-db"
  }
}

# Private DB Subnet - AZ C
resource "aws_subnet" "private_db_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.21.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-db-c"
    Tier = "private-db"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# Public Subnet Route Table Association
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}