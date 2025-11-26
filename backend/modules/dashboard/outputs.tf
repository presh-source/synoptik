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
  value       = var.frontend_domain_name != "" ? "https://${var.frontend_domain_name}" : "https://${aws_cloudfront_distribution.dashboard.domain_name}"
}

# Domain and certificate outputs
output "frontend_domain_name" {
  description = "Custom domain name for the frontend"
  value       = var.frontend_domain_name != "" ? var.frontend_domain_name : null
}

output "api_gateway_domain_name" {
  description = "Custom domain name for the API"
  value       = var.api_gateway_domain_name != "" ? var.api_gateway_domain_name : null
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (length(module.frontend_certificate) > 0 ? module.frontend_certificate[0].certificate_arn : null)
}

output "appsync_api_url" {
  description = "The URL of the AppSync GraphQL API"
  value       = module.appsync.appsync_api_url
}

output "appsync_api_id" {
  description = "The ID of the AppSync GraphQL API"
  value       = module.appsync.appsync_api_id
}

output "appsync_realtime_url" {
  description = "WebSocket endpoint URL for subscriptions"
  value       = module.appsync.appsync_realtime_url
}

output "appsync_api_key" {
  description = "API key for AppSync GraphQL API"
  value       = module.appsync.appsync_api_key
  sensitive   = true
}
