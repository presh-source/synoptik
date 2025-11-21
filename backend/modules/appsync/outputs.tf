# Outputs for AppSync Module

# ============================================================================
# AppSync API Outputs
# ============================================================================

output "appsync_api_id" {
  description = "ID of the AppSync GraphQL API"
  value       = aws_appsync_graphql_api.main.id
}

output "appsync_api_arn" {
  description = "ARN of the AppSync GraphQL API"
  value       = aws_appsync_graphql_api.main.arn
}

output "appsync_api_url" {
  description = "GraphQL endpoint URL for queries and mutations"
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
}

output "appsync_realtime_endpoint" {
  description = "WebSocket endpoint URL for subscriptions"
  value       = aws_appsync_graphql_api.main.uris["REALTIME"]
}

output "appsync_api_key" {
  description = "API key for AppSync GraphQL API"
  value       = aws_appsync_api_key.main.key
  sensitive   = true
}

# ============================================================================
# Lambda Function ARNs
# ============================================================================

output "pipeline_status_resolver_lambda_arn" {
  description = "ARN of the pipeline status resolver Lambda function"
  value       = aws_lambda_function.pipeline_status_resolver.arn
}

output "crawler_metrics_resolver_lambda_arn" {
  description = "ARN of the crawler metrics resolver Lambda function"
  value       = aws_lambda_function.crawler_metrics_resolver.arn
}

output "error_rates_resolver_lambda_arn" {
  description = "ARN of the error rates resolver Lambda function"
  value       = aws_lambda_function.error_rates_resolver.arn
}

# ============================================================================
# Lambda Function Names
# ============================================================================

output "pipeline_status_resolver_lambda_name" {
  description = "Name of the pipeline status resolver Lambda function"
  value       = aws_lambda_function.pipeline_status_resolver.function_name
}

output "crawler_metrics_resolver_lambda_name" {
  description = "Name of the crawler metrics resolver Lambda function"
  value       = aws_lambda_function.crawler_metrics_resolver.function_name
}

output "error_rates_resolver_lambda_name" {
  description = "Name of the error rates resolver Lambda function"
  value       = aws_lambda_function.error_rates_resolver.function_name
}

# ============================================================================
# IAM Roles
# ============================================================================

output "appsync_lambda_role_arn" {
  description = "ARN of the IAM role for AppSync to invoke Lambda functions"
  value       = aws_iam_role.appsync_lambda_role.arn
}

# ============================================================================
# Secrets Manager
# ============================================================================

output "appsync_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the AppSync API key"
  value       = aws_secretsmanager_secret.appsync_api_key.arn
}

# ============================================================================
# Custom Domain
# ============================================================================

output "appsync_domain_name" {
  description = "The AppSync domain name (for DNS configuration)"
  value       = length(aws_appsync_domain_name.main) > 0 ? aws_appsync_domain_name.main[0].appsync_domain_name : null
}

output "appsync_hosted_zone_id" {
  description = "The hosted zone ID for the AppSync domain (for DNS configuration)"
  value       = length(aws_appsync_domain_name.main) > 0 ? aws_appsync_domain_name.main[0].hosted_zone_id : null
}
