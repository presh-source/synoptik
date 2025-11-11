# Cold Path Module - Outputs

output "dynamodb_table_name" {
  description = "Name of the DynamoDB CrawlState table"
  value       = aws_dynamodb_table.crawl_state.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB CrawlState table"
  value       = aws_dynamodb_table.crawl_state.arn
}

output "crawler_lambda_arn" {
  description = "ARN of the CrawlerLambda function"
  value       = aws_lambda_function.crawler.arn
}

output "crawler_lambda_name" {
  description = "Name of the CrawlerLambda function"
  value       = aws_lambda_function.crawler.function_name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.crawler_schedule.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.crawler_alerts.arn
}
