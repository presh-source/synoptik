# API Gateway Module - Outputs

output "rest_api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.api.id
}

output "rest_api_arn" {
  description = "ARN of the REST API"
  value       = aws_api_gateway_rest_api.api.arn
}

output "rest_api_execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.api.execution_arn
}

output "rest_api_root_resource_id" {
  description = "Root resource ID of the REST API"
  value       = aws_api_gateway_rest_api.api.root_resource_id
}

output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.api.stage_name
}

output "stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = aws_api_gateway_stage.api.arn
}

output "invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  value       = aws_api_gateway_stage.api.invoke_url
}

output "deployment_id" {
  description = "ID of the API Gateway deployment"
  value       = aws_api_gateway_deployment.api.id
}

output "custom_domain_name" {
  description = "Custom domain name (if configured)"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.api[0].domain_name : null
}

output "custom_domain_cloudfront_domain_name" {
  description = "CloudFront domain name for custom domain (for DNS)"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.api[0].cloudfront_domain_name : null
}

output "custom_domain_cloudfront_zone_id" {
  description = "CloudFront zone ID for custom domain (for DNS)"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.api[0].cloudfront_zone_id : null
}

output "api_url" {
  description = "Full URL of the API (custom domain if configured, otherwise invoke URL)"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}${var.base_path != "" ? "/${var.base_path}" : ""}" : aws_api_gateway_stage.api.invoke_url
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

output "resources" {
  description = "Map of created API Gateway resources"
  value = {
    for k, v in aws_api_gateway_resource.resources : k => {
      id   = v.id
      path = v.path
    }
  }
}
