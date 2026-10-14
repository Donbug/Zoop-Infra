variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "zoop"
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "dev"
}

variable "api_container_port" {
  description = "API Fargate container port"
  type        = number
  default     = 8080

  validation {
    condition     = var.api_container_port >= 1 && var.api_container_port <= 65535
    error_message = "API container port must be between 1 and 65535."
  }
}

variable "ai_container_port" {
  description = "AI Fargate container port"
  type        = number
  default     = 8000

  validation {
    condition     = var.ai_container_port >= 1 && var.ai_container_port <= 65535
    error_message = "AI container port must be between 1 and 65535."
  }
}

variable "rds_engine_version" {
  description = "PostgreSQL major engine version"
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "RDS PostgreSQL instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_database_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "zoop"
}

variable "rds_master_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "zoop_admin"
}

variable "rds_allocated_storage" {
  description = "Initial RDS storage size in GiB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Maximum RDS autoscaling storage size in GiB"
  type        = number
  default     = 100
}

variable "rds_backup_retention_period" {
  description = "RDS automated backup retention period in days"
  type        = number
  default     = 1
}

variable "valkey_engine_version" {
  description = "ElastiCache Valkey engine version"
  type        = string
  default     = "7.2"
}

variable "valkey_node_type" {
  description = "ElastiCache Valkey node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "valkey_port" {
  description = "ElastiCache Valkey port"
  type        = number
  default     = 6379
}

variable "neo4j_instance_type" {
  description = "EC2 instance type for the Neo4j host"
  type        = string
  default     = "t3.small"
}

variable "neo4j_root_volume_size" {
  description = "Neo4j EC2 root volume size in GiB"
  type        = number
  default     = 10
}

variable "neo4j_data_volume_size" {
  description = "Neo4j data EBS volume size in GiB"
  type        = number
  default     = 20
}