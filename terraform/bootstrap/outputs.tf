output "terraform_state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_state_key" {
  description = "Recommended S3 object key for the dev environment state"
  value       = "zoop/dev/terraform.tfstate"
}