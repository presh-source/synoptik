# EventBridge Resources

# --------------------------------------------------------------------------------------------------
# Repo Crawler Schedule
# --------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "repo_crawler_schedule" {
  name                = "${var.environment}-${var.project_name}-repo-crawler-schedule"
  description         = "Trigger ${var.project_name} repo crawler Lambda every 15 minutes"
  schedule_expression = "rate(15 minutes)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "repo_crawler_lambda" {
  rule      = aws_cloudwatch_event_rule.repo_crawler_schedule.name
  target_id = "RepoCrawlerLambdaTarget"
  arn       = module.repo_crawler.function_arn
}

resource "aws_lambda_permission" "allow_eventbridge_repo_crawler" {
  statement_id  = "AllowExecutionFromEventBridgeRepo"
  action        = "lambda:InvokeFunction"
  function_name = module.repo_crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.repo_crawler_schedule.arn
}

# --------------------------------------------------------------------------------------------------
# User Crawler Schedule
# --------------------------------------------------------------------------------------------------

# resource "aws_cloudwatch_event_rule" "user_crawler_schedule" {
#   name                = "${var.environment}-${var.project_name}-user-crawler-schedule"
#   description         = "Trigger ${var.project_name} user crawler Lambda every 15 minutes"
#   schedule_expression = "rate(15 minutes)"

#   tags = var.tags
# }

# resource "aws_cloudwatch_event_target" "user_crawler_lambda" {
#   rule      = aws_cloudwatch_event_rule.user_crawler_schedule.name
#   target_id = "UserCrawlerLambdaTarget"
#   arn       = module.user_crawler.function_arn
# }

# resource "aws_lambda_permission" "allow_eventbridge_user_crawler" {
#   statement_id  = "AllowExecutionFromEventBridgeUser"
#   action        = "lambda:InvokeFunction"
#   function_name = module.user_crawler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.user_crawler_schedule.arn
# }

# --------------------------------------------------------------------------------------------------
# GitHub Crawler Schedules (Unified Crawler)
# --------------------------------------------------------------------------------------------------

# Repo Crawling Schedule
# resource "aws_cloudwatch_event_rule" "github_repo_crawler_schedule" {
#   name                = "${var.environment}-${var.project_name}-github-repo-crawler-schedule"
#   description         = "Trigger GitHub unified crawler for repositories every 15 minutes"
#   schedule_expression = "rate(15 minutes)"

#   tags = var.tags
# }

# resource "aws_cloudwatch_event_target" "github_repo_crawler_lambda" {
#   rule      = aws_cloudwatch_event_rule.github_repo_crawler_schedule.name
#   target_id = "GitHubRepoCrawlerLambdaTarget"
#   arn       = module.github_crawler.function_arn

#   input = jsonencode({
#     crawler_type = "repo"
#   })
# }

# resource "aws_lambda_permission" "allow_eventbridge_github_repo_crawler" {
#   statement_id  = "AllowExecutionFromEventBridgeGitHubRepo"
#   action        = "lambda:InvokeFunction"
#   function_name = module.github_crawler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.github_repo_crawler_schedule.arn
# }

# # User Crawling Schedule
# resource "aws_cloudwatch_event_rule" "github_user_crawler_schedule" {
#   name                = "${var.environment}-${var.project_name}-github-user-crawler-schedule"
#   description         = "Trigger GitHub unified crawler for users every 15 minutes"
#   schedule_expression = "rate(15 minutes)"

#   tags = var.tags
# }

# resource "aws_cloudwatch_event_target" "github_user_crawler_lambda" {
#   rule      = aws_cloudwatch_event_rule.github_user_crawler_schedule.name
#   target_id = "GitHubUserCrawlerLambdaTarget"
#   arn       = module.github_crawler.function_arn

#   input = jsonencode({
#     crawler_type = "user"
#   })
# }

# resource "aws_lambda_permission" "allow_eventbridge_github_user_crawler" {
#   statement_id  = "AllowExecutionFromEventBridgeGitHubUser"
#   action        = "lambda:InvokeFunction"
#   function_name = module.github_crawler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.github_user_crawler_schedule.arn
# }

# --------------------------------------------------------------------------------------------------
# Telemetry Event Rule
# --------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "crawler_events" {
  name        = "${var.environment}-${var.project_name}-crawler-completion"
  description = "Capture crawler completion events"

  event_pattern = jsonencode({
    source      = ["${var.project_name}.crawler"]
    detail-type = ["CrawlerCompleted"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "telemetry_lambda" {
  rule      = aws_cloudwatch_event_rule.crawler_events.name
  target_id = "TelemetryLambdaTarget"
  arn       = module.telemetry.function_arn

  dead_letter_config {
    arn = aws_sqs_queue.telemetry_dlq.arn
  }
}

resource "aws_lambda_permission" "allow_eventbridge_telemetry" {
  statement_id  = "AllowExecutionFromEventBridgeTelemetry"
  action        = "lambda:InvokeFunction"
  function_name = module.telemetry.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crawler_events.arn
}

# --------------------------------------------------------------------------------------------------
# Aggregator Hourly Schedule
# --------------------------------------------------------------------------------------------------

# resource "aws_cloudwatch_event_rule" "aggregator_schedule" {
#   name                = "${var.environment}-${var.project_name}-aggregator-schedule"
#   description         = "Trigger hourly aggregation of crawler metrics"
#   schedule_expression = "cron(0 * * * ? *)" # Every hour at minute 0

#   tags = var.tags
# }

# resource "aws_cloudwatch_event_target" "aggregator_lambda" {
#   rule      = aws_cloudwatch_event_rule.aggregator_schedule.name
#   target_id = "AggregatorLambdaTarget"
#   arn       = module.aggregator.function_arn
# }

# resource "aws_lambda_permission" "allow_eventbridge_aggregator" {
#   statement_id  = "AllowExecutionFromEventBridgeAggregator"
#   action        = "lambda:InvokeFunction"
#   function_name = module.aggregator.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.aggregator_schedule.arn
# }
