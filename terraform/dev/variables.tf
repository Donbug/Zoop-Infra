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