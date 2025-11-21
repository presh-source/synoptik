# Outputs

# ============================================================================
# Implemented Module Outputs
# ============================================================================

output "data_lake_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  value       = module.data_lake.bucket_name
}

output "dashboard_api_url" {
  description = "URL of the Dashboard API Gateway"
  value       = module.dashboard.api_gateway_url
}

output "dashboard_bucket_name" {
  description = "Name of the S3 bucket hosting the dashboard"
  value       = module.dashboard.dashboard_bucket_name
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.dashboard.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.dashboard.cloudfront_distribution_id
}

output "dashboard_url" {
  description = "URL of the dashboard"
  value       = module.dashboard.dashboard_url
}

# ============================================================================
# AppSync GraphQL API Outputs
# ============================================================================

output "appsync_api_url" {
  description = "GraphQL endpoint URL for queries and mutations"
  value       = module.appsync.appsync_api_url
}

output "appsync_realtime_endpoint" {
  description = "WebSocket endpoint URL for subscriptions"
  value       = module.appsync.appsync_realtime_endpoint
}

output "appsync_api_key" {
  description = "API key for AppSync GraphQL API"
  value       = module.appsync.appsync_api_key
  sensitive   = true
}

output "appsync_api_id" {
  description = "ID of the AppSync GraphQL API"
  value       = module.appsync.appsync_api_id
}
