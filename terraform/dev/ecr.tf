# API와 AI 컨테이너 이미지 저장소 이름
locals {
  ecr_repositories = {
    api             = lower("${var.project_name}-${var.environment}-api")
    ai              = lower("${var.project_name}-${var.environment}-ai")
    "ai-collection" = lower("${var.project_name}-${var.environment}-ai-collection")
  }
}

# API/AI Amazon ECR Repository
resource "aws_ecr_repository" "service" {
  for_each = local.ecr_repositories

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = each.value
    Service = each.key
  }
}

# 오래된 컨테이너 이미지 자동 정리
resource "aws_ecr_lifecycle_policy" "service" {
  for_each = aws_ecr_repository.service

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 7 days"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the 10 most recent images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}