# GitHub Digital Twin - Outputs

output "data_lake_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  value       = module.data_lake.bucket_name
}

output "cold_path_dynamodb_table" {
  description = "Name of the Cold Path DynamoDB state table"
  value       = module.cold_path.dynamodb_table_name
}

output "cold_path_lambda_arn" {
  description = "ARN of the CrawlerLambda function"
  value       = module.cold_path.crawler_lambda_arn
}

output "hot_path_kinesis_stream" {
  description = "Name of the Kinesis Data Stream"
  value       = module.hot_path.kinesis_stream_name
}

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch cluster"
  value       = module.data_stores.opensearch_endpoint
  sensitive   = true
}

output "neptune_endpoint" {
  description = "Endpoint of the Neptune cluster"
  value       = module.data_stores.neptune_endpoint
  sensitive   = true
}

output "dashboard_api_url" {
  description = "URL of the Dashboard API Gateway"
  value       = module.dashboard.api_gateway_url
}

output "dashboard_frontend_url" {
  description = "URL of the Dashboard frontend"
  value       = module.dashboard.frontend_url
}

output "github_token_secret_arn" {
  description = "ARN of the GitHub token in Secrets Manager"
  value       = module.secrets.github_token_arn
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch monitoring dashboard"
  value       = module.monitoring.dashboard_url
}
