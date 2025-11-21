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
  description = "ARN of the RepoCrawlerLambda function"
  value       = aws_lambda_function.repo_crawler.arn
}

output "crawler_lambda_name" {
  description = "Name of the RepoCrawlerLambda function"
  value       = aws_lambda_function.repo_crawler.function_name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for the repo crawler"
  value       = aws_cloudwatch_event_rule.repo_crawler_schedule.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for repo crawler alerts"
  value       = aws_sns_topic.repo_crawler_alerts.arn
}

output "user_crawler_lambda_arn" {
  description = "ARN of the UserCrawlerLambda function"
  value       = aws_lambda_function.user_crawler.arn
}

output "user_crawler_lambda_name" {
  description = "Name of the UserCrawlerLambda function"
  value       = aws_lambda_function.user_crawler.function_name
}

output "user_crawler_eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for the user crawler"
  value       = aws_cloudwatch_event_rule.user_crawler_schedule.arn
}

output "repo_crawler_lambda_role_arn" {
  description = "ARN of the IAM role for the repo crawler Lambda"
  value       = aws_iam_role.repo_crawler_lambda.arn
}

output "user_crawler_lambda_role_arn" {
  description = "ARN of the IAM role for the user crawler Lambda"
  value       = aws_iam_role.user_crawler_lambda.arn
}
