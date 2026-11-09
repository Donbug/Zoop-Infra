data "aws_caller_identity" "current" {}

data "aws_vpc" "existing" {
  id = var.existing.vpc_id
}

data "aws_subnet" "private" {
  for_each = var.existing.private_subnet_ids
  id       = each.value
  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.existing.vpc_id && !self.map_public_ip_on_launch
      error_message = "Both approved subnets must belong to the VPC and have public address assignment disabled."
    }
  }
}

data "aws_security_group" "shared" {
  for_each = { efs = var.existing.efs_security_group, rds = var.existing.rds_security_group }
  id       = each.value
  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.existing.vpc_id
      error_message = "Shared EFS/RDS SG metadata must match the approved VPC."
    }
  }
}

data "aws_efs_file_system" "existing" {
  file_system_id = var.existing.efs_id
  lifecycle {
    postcondition {
      condition     = self.encrypted && self.arn == local.fs_arn
      error_message = "The existing EFS must be encrypted and owned by the approved account."
    }
  }
}

data "aws_efs_access_point" "existing" {
  for_each        = var.existing.access_points
  access_point_id = each.value
  lifecycle {
    postcondition {
      condition     = self.file_system_id == var.existing.efs_id && self.owner_id == var.expected_account_id
      error_message = "Every existing AP must belong to the approved filesystem/account."
    }
  }
}

data "aws_ecs_cluster" "existing" {
  cluster_name = var.existing.cluster_arn
}

data "aws_ecr_repository" "image" {
  for_each = { reader = var.images.reader, operator = var.images.operator }
  name     = split("repository/", each.value.repository_arn)[1]
  lifecycle {
    postcondition {
      condition     = self.arn == each.value.repository_arn && startswith(each.value.pin, "${self.repository_url}@sha256:")
      error_message = "Image repository metadata must match the exact approved pin and ARN."
    }
  }
}

data "aws_secretsmanager_secret" "existing" {
  for_each = { database = var.database.credentials_arn, csrf = var.database.csrf_secret_arn }
  arn      = each.value
}

locals {
  profiles = toset(["existing2", "six", "three", "eu11"])
  name     = "zoop-dev-operational69"
  fs_arn   = "arn:aws:elasticfilesystem:${var.aws_region}:${var.expected_account_id}:file-system/${var.existing.efs_id}"
}
