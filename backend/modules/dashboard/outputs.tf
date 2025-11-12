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
  value       = var.use_localstack ? null : aws_cloudfront_distribution.dashboard[0].id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = var.use_localstack ? null : aws_cloudfront_distribution.dashboard[0].domain_name
}

output "dashboard_url" {
  description = "URL of the dashboard"
  value       = var.use_localstack ? null : (var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.dashboard[0].domain_name}")
}

output "api_url" {
  description = "URL of the API"
  value       = var.api_domain_name != "" ? "https://${var.api_domain_name}/api" : "${aws_api_gateway_stage.dashboard.invoke_url}/api"
}

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
  value       = var.acm_certificate_arn != "" ? var.acm_certificate_arn : ((var.domain_name != "" || var.api_domain_name != "") ? aws_acm_certificate.dashboard[0].arn : null)
}
