terraform {
  required_version = ">= 1.16.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.29.0"
    }
  }
  backend "s3" {
    key          = "zoop/dev/operational69/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]
  default_tags {
    tags = {
      Project     = "zoop"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Purpose     = "operational69"
    }
  }
}
