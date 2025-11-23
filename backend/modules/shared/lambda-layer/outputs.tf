# Lambda Layer Module - Outputs

output "arn" {
  description = "ARN of the Lambda Layer version"
  value       = aws_lambda_layer_version.this.arn
}

output "layer_id" {
  description = "The name of the lambda layer"
  value       = aws_lambda_layer_version.this.layer_name
}

output "version" {
  description = "The version of the lambda layer"
  value       = aws_lambda_layer_version.this.version
}
