# Secrets Module - Outputs

output "github_token_arn" {
  description = "ARN of the GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.arn
}

output "github_token_name" {
  description = "Name of the GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.name
}
