# IAM Module - Outputs

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "glue_execution_role_arn" {
  description = "ARN of the Glue execution role"
  value       = aws_iam_role.glue_execution.arn
}

output "glue_execution_role_name" {
  description = "Name of the Glue execution role"
  value       = aws_iam_role.glue_execution.name
}

output "eventbridge_role_arn" {
  description = "ARN of the EventBridge role"
  value       = aws_iam_role.eventbridge.arn
}

output "firehose_role_arn" {
  description = "ARN of the Firehose role"
  value       = aws_iam_role.firehose.arn
}

output "api_gateway_cloudwatch_role_arn" {
  description = "ARN of the API Gateway CloudWatch Logs role"
  value       = aws_iam_role.api_gateway_cloudwatch.arn
}
