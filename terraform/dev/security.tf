# -------------------------------------------------------------------
# Security Groups
# -------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for the internal ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

resource "aws_security_group" "api" {
  name        = "${var.project_name}-${var.environment}-api-sg"
  description = "Security group for the API Fargate service"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-api-sg"
  }
}

resource "aws_security_group" "ai" {
  name        = "${var.project_name}-${var.environment}-ai-sg"
  description = "Security group for the AI Fargate service"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

resource "aws_security_group" "neo4j" {
  name        = "${var.project_name}-${var.environment}-neo4j-sg"
  description = "Security group for the Neo4j EC2 instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-neo4j-sg"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis or Valkey"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-sg"
  }
}

# -------------------------------------------------------------------
# Internal ALB
# CloudFront VPC Origin 생성 전에는 VPC 내부에서만 HTTP 접근 허용
# -------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_vpc" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from within the VPC"
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests to the API Fargate service"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = var.api_container_port
  to_port                      = var.api_container_port
  ip_protocol                  = "tcp"
}

# -------------------------------------------------------------------
# API Fargate
# -------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api.id
  description                  = "Allow API traffic from the internal ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.api_container_port
  to_port                      = var.api_container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "api_all_egress" {
  security_group_id = aws_security_group.api.id
  description       = "Allow API outbound traffic for AWS and external APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -------------------------------------------------------------------
# AI Fargate
# API에서만 AI 서비스에 접근 가능
# -------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "ai_from_api" {
  security_group_id            = aws_security_group.ai.id
  description                  = "Allow AI service traffic from the API service"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = var.ai_container_port
  to_port                      = var.ai_container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ai_all_egress" {
  security_group_id = aws_security_group.ai.id
  description       = "Allow AI outbound traffic for AWS and external APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -------------------------------------------------------------------
# RDS PostgreSQL
# -------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "rds_from_api" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow PostgreSQL traffic from the API service"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ai" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow PostgreSQL traffic from the AI service"
  referenced_security_group_id = aws_security_group.ai.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# -------------------------------------------------------------------
# Neo4j EC2
# Bolt 포트만 API/AI에서 허용하며 SSH와 Browser 포트는 열지 않는다.
# -------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "neo4j_from_api" {
  security_group_id            = aws_security_group.neo4j.id
  description                  = "Allow Neo4j Bolt traffic from the API service"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 7687
  to_port                      = 7687
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "neo4j_from_ai" {
  security_group_id            = aws_security_group.neo4j.id
  description                  = "Allow Neo4j Bolt traffic from the AI service"
  referenced_security_group_id = aws_security_group.ai.id
  from_port                    = 7687
  to_port                      = 7687
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "neo4j_all_egress" {
  security_group_id = aws_security_group.neo4j.id
  description       = "Allow outbound traffic for SSM, packages, and S3 backup"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -------------------------------------------------------------------
# ElastiCache Redis / Valkey
# -------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "redis_from_api" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Allow Redis traffic from the API service"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ai" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Allow Redis traffic from the AI service"
  referenced_security_group_id = aws_security_group.ai.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}