variable "aws_region" {
  description = "AWS region used for the Terraform state bucket"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "zoop"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}