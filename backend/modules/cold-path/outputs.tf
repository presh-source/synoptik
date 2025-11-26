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
  value       = module.telemetry.function_arn
}

output "aggregator_lambda_arn" {
  description = "ARN of the aggregator Lambda"
  value       = module.aggregator.function_arn
}

output "telemetry_dlq_url" {
  description = "URL of the telemetry Dead Letter Queue"
  value       = aws_sqs_queue.telemetry_dlq.url
}

output "telemetry_dlq_arn" {
  description = "ARN of the telemetry Dead Letter Queue"
  value       = aws_sqs_queue.telemetry_dlq.arn
}

output "aggregator_dlq_url" {
  description = "URL of the aggregator Dead Letter Queue"
  value       = aws_sqs_queue.aggregator_dlq.url
}

output "aggregator_dlq_arn" {
  description = "ARN of the aggregator Dead Letter Queue"
  value       = aws_sqs_queue.aggregator_dlq.arn
}
