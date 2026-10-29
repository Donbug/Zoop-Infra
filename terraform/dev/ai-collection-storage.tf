locals {
  ai_collection_bucket_name = "${local.ecs_name}-ai-collection-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "ai_collection" {
  bucket        = local.ai_collection_bucket_name
  force_destroy = false

  tags = {
    Name    = local.ai_collection_bucket_name
    Service = "ai-collection"
  }
}

resource "aws_s3_bucket_ownership_controls" "ai_collection" {
  bucket = aws_s3_bucket.ai_collection.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "ai_collection" {
  bucket = aws_s3_bucket.ai_collection.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_collection" {
  bucket = aws_s3_bucket.ai_collection.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "ai_collection" {
  bucket = aws_s3_bucket.ai_collection.id

  versioning_configuration {
    status = "Enabled"
  }
}