output "repository_urls" {
  description = "ECR repository URLs keyed by service name"
  value       = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}

output "repository_arns" {
  description = "ECR repository ARNs keyed by service name"
  value       = { for name, repository in aws_ecr_repository.service : name => repository.arn }
}
