# Dashboard Module Outputs

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.dashboard.id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_stage.dashboard.invoke_url
}

output "pipeline_status_lambda_arn" {
  description = "ARN of the pipeline status Lambda function"
  value       = aws_lambda_function.pipeline_status.arn
}

output "realtime_metrics_lambda_arn" {
  description = "ARN of the realtime metrics Lambda function"
  value       = aws_lambda_function.realtime_metrics.arn
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
  value       = "https://${aws_cloudfront_distribution.dashboard.domain_name}"
}
