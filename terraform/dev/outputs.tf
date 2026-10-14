output "ecr_repository_urls" {
  description = "Repository URLs for the API and AI container images"

  value = {
    for service, repository in aws_ecr_repository.service :
    service => repository.repository_url
  }
}