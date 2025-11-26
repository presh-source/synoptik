output "dynamodb_table_name" {
  value = aws_dynamodb_table.crawl_state.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.crawl_state.arn
}

output "repo_crawler_lambda_arn" {
  value = module.repo_crawler.function_arn
}

output "user_crawler_lambda_arn" {
  value = module.user_crawler.function_arn
}

output "telemetry_table_name" {
  description = "Name of the telemetry DynamoDB table"
  value       = aws_dynamodb_table.telemetry.name
}

output "telemetry_table_arn" {
  description = "ARN of the telemetry DynamoDB table"
  value       = aws_dynamodb_table.telemetry.arn
}

output "telemetry_lambda_arn" {
  description = "ARN of the telemetry processor Lambda"
  value       = module.telemetry_processor.function_arn
}

output "telemetry_aggregator_lambda_arn" {
  description = "ARN of the telemetry aggregator Lambda"
  value       = module.telemetry_aggregator.function_arn
}

output "telemetry_processor_dlq_url" {
  description = "URL of the telemetry processor Dead Letter Queue"
  value       = aws_sqs_queue.telemetry_processor_dlq.url
}

output "telemetry_processor_dlq_arn" {
  description = "ARN of the telemetry processor Dead Letter Queue"
  value       = aws_sqs_queue.telemetry_processor_dlq.arn
}

output "telemetry_aggregator_dlq_url" {
  description = "URL of the telemetry aggregator Dead Letter Queue"
  value       = aws_sqs_queue.telemetry_aggregator_dlq.url
}

output "telemetry_aggregator_dlq_arn" {
  description = "ARN of the telemetry aggregator Dead Letter Queue"
  value       = aws_sqs_queue.telemetry_aggregator_dlq.arn
}
