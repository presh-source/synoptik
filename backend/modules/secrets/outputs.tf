# Secrets Module - Outputs

output "github_token_arn" {
  description = "ARN of the GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.arn
}

output "github_token_name" {
  description = "Name of the GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.name
}


output "sentry_dsn_frontend_arn" {
  description = "ARN of the Sentry frontend DSN secret"
  value       = aws_secretsmanager_secret.sentry_dsn_frontend.arn
}

output "sentry_dsn_backend_arn" {
  description = "ARN of the Sentry backend DSN secret"
  value       = aws_secretsmanager_secret.sentry_dsn_backend.arn
}
