# Monitoring Resources

# --------------------------------------------------------------------------------------------------
# SQS Dead Letter Queue
# --------------------------------------------------------------------------------------------------

resource "aws_sqs_queue" "telemetry_dlq" {
  name                      = "${var.environment}-${var.project_name}-telemetry-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = var.tags
}

resource "aws_sqs_queue" "aggregator_dlq" {
  name                      = "${var.environment}-${var.project_name}-aggregator-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = var.tags
}

# --------------------------------------------------------------------------------------------------
# Repo Crawler Monitoring
# --------------------------------------------------------------------------------------------------

resource "aws_sns_topic" "repo_crawler_alerts" {
  name = "${var.environment}-${var.project_name}-repo-crawler-alerts"
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "repo_crawler_errors" {
  alarm_name          = "${var.environment}-${var.project_name}-repo-crawler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Alert when repo crawler Lambda has more than 3 errors in 30 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.repo_crawler.function_name
  }

  alarm_actions = [aws_sns_topic.repo_crawler_alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "repo_crawler_throttles" {
  alarm_name          = "${var.environment}-${var.project_name}-repo-crawler-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when repo crawler Lambda is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.repo_crawler.function_name
  }

  alarm_actions = [aws_sns_topic.repo_crawler_alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "repo_crawler_progress" {
  name           = "${var.environment}-repo-crawler-progress"
  log_group_name = module.repo_crawler.log_group_name
  pattern        = "[time, request_id, level=INFO, msg=\"Crawl complete:\", ...]"

  metric_transformation {
    name      = "RepoCrawlerProgress"
    namespace = "${title(var.project_name)}/ColdPath"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "repositories_processed" {
  name           = "${var.environment}-repositories-processed"
  log_group_name = module.repo_crawler.log_group_name
  pattern        = "[time, request_id, level=INFO, msg=\"Saved\", count, repositories=repositories, ...]"

  metric_transformation {
    name      = "RepositoriesProcessed"
    namespace = "${title(var.project_name)}/ColdPath"
    value     = "$count"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "repo_crawler_stalled" {
  alarm_name          = "${var.environment}-${var.project_name}-repo-crawler-stalled"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RepoCrawlerProgress"
  namespace           = "${title(var.project_name)}/ColdPath"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when repo crawler has made no progress in 30 minutes"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.repo_crawler_alerts.arn]

  tags = var.tags
}

# --------------------------------------------------------------------------------------------------
# User Crawler Monitoring
# --------------------------------------------------------------------------------------------------

resource "aws_sns_topic" "user_crawler_alerts" {
  name = "${var.environment}-${var.project_name}-user-crawler-alerts"
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "user_crawler_errors" {
  alarm_name          = "${var.environment}-${var.project_name}-user-crawler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Alert when user crawler Lambda has more than 3 errors in 30 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.user_crawler.function_name
  }

  alarm_actions = [aws_sns_topic.user_crawler_alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "user_crawler_throttles" {
  alarm_name          = "${var.environment}-${var.project_name}-user-crawler-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when user crawler Lambda is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.user_crawler.function_name
  }

  alarm_actions = [aws_sns_topic.user_crawler_alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "user_crawler_progress" {
  name           = "${var.environment}-user-crawler-progress"
  log_group_name = module.user_crawler.log_group_name
  pattern        = "[time, request_id, level=INFO, msg=\"Crawl complete:\", ...]"

  metric_transformation {
    name      = "UserCrawlerProgress"
    namespace = "${title(var.project_name)}/ColdPath"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "users_processed" {
  name           = "${var.environment}-users-processed"
  log_group_name = module.user_crawler.log_group_name
  pattern        = "[time, request_id, level=INFO, msg=\"Saved\", count, users=users, ...]"

  metric_transformation {
    name      = "UsersProcessed"
    namespace = "${title(var.project_name)}/ColdPath"
    value     = "$count"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "user_crawler_stalled" {
  alarm_name          = "${var.environment}-${var.project_name}-user-crawler-stalled"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UserCrawlerProgress"
  namespace           = "${title(var.project_name)}/ColdPath"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when user crawler has made no progress in 30 minutes"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.user_crawler_alerts.arn]

  tags = var.tags
}
