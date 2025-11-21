# Dashboard Module Outputs

# API Gateway outputs (from api-gateway module)
output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = module.dashboard_api.rest_api_id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.dashboard_api.invoke_url
}

output "api_url" {
  description = "Full URL of the API (custom domain or invoke URL)"
  value       = module.dashboard_api.api_url
}

# Lambda outputs
output "pipeline_status_lambda_arn" {
  description = "ARN of the pipeline status Lambda function"
  value       = aws_lambda_function.pipeline_status.arn
}

output "cloudwatch_metrics_lambda_arn" {
  description = "ARN of the CloudWatch metrics Lambda function"
  value       = aws_lambda_function.cloudwatch_metrics.arn
}

# Frontend outputs
output "dashboard_bucket_name" {
  description = "Name of the S3 bucket hosting the dashboard"
  value       = aws_s3_bucket.dashboard.id
}

output "dashboard_bucket_arn" {
  description = "ARN of the S3 bucket hosting the dashboard"
  value       = aws_s3_bucket.dashboard.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.dashboard.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.dashboard.domain_name
}

output "dashboard_url" {
  description = "URL of the dashboard"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.dashboard.domain_name}"
}

# Domain and certificate outputs
output "domain_name" {
  description = "Custom domain name for the frontend"
  value       = var.domain_name != "" ? var.domain_name : null
}

output "api_domain_name" {
  description = "Custom domain name for the API"
  value       = var.api_domain_name != "" ? var.api_domain_name : null
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (length(module.frontend_certificate) > 0 ? module.frontend_certificate[0].certificate_arn : null)
}

output "appsync_graphql_api_url" {
  description = "The URL of the AppSync GraphQL API"
  value       = var.appsync_graphql_api_url
}

output "appsync_api_key" {
  description = "The API Key for the AppSync GraphQL API"
  value       = var.appsync_api_key
  sensitive   = true
}

output "appsync_custom_domain_url" {
  description = "The custom domain URL for the AppSync GraphQL API"
  value       = var.appsync_graphql_domain_name != "" ? "https://{var.appsync_graphql_domain_name}/graphql" : null
}

output "appsync_domain_name" {
  description = "The AppSync domain name (for DNS configuration)"
  value       = var.appsync_domain_name
}

output "appsync_hosted_zone_id" {
  description = "The hosted zone ID for the AppSync domain (for DNS configuration)"
  value       = var.appsync_hosted_zone_id
}

output "appsync_graphql_domain_name" {
  description = "Custom domain name for the GraphQL API"
  value       = var.appsync_graphql_domain_name != "" ? var.appsync_graphql_domain_name : null
}
