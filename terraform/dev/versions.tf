terraform {
  required_version = ">= 1.16.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.29.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
  }
}