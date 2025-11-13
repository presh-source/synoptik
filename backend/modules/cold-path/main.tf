# Cold Path Module - GitHub Repository Crawler Pipeline

# Get current AWS region
data "aws_region" "current" {}

# DynamoDB table for crawler state management
resource "aws_dynamodb_table" "crawl_state" {
  name         = "${var.environment}-${var.project_name}-crawler-state"
  billing_mode = "PAY_PER_REQUEST" # On-demand capacity
  hash_key     = "state_key"

  attribute {
    name = "state_key"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = true

  tags = var.tags
}

# Initialize the bookmark with last_processed_id = 0
resource "aws_dynamodb_table_item" "initial_bookmark" {
  table_name = aws_dynamodb_table.crawl_state.name
  hash_key   = aws_dynamodb_table.crawl_state.hash_key

  item = jsonencode({
    state_key = {
      S = "bookmark"
    }
    last_processed_id = {
      N = "0"
    }
    total_processed = {
      N = "0"
    }
    updated_at = {
      S = timestamp()
    }
  })

  lifecycle {
    ignore_changes = [item] # Don't overwrite on subsequent applies
  }
}

# IAM role for CrawlerLambda
resource "aws_iam_role" "crawler_lambda" {
  name = "${var.environment}-${var.project_name}-crawler-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "crawler_lambda_basic" {
  role       = aws_iam_role.crawler_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for CrawlerLambda
resource "aws_iam_role_policy" "crawler_lambda_policy" {
  name = "${var.environment}-${var.project_name}-crawler-lambda-policy"
  role = aws_iam_role.crawler_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.crawl_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.data_lake_bucket_name}/cold-path/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.github_token_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Install Lambda dependencies locally
resource "null_resource" "install_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/lambda/requirements.txt")
  }

  provisioner "local-exec" {
    command     = <<-EOT
      rm -rf lambda_build
      mkdir -p lambda_build/python
      pip install -r lambda/requirements.txt -t lambda_build/python --upgrade --quiet
      # Create a marker file to indicate successful installation
      echo "Dependencies installed at $(date)" > lambda_build/.installed
    EOT
    working_dir = path.module
  }
}

# Package Lambda dependencies as a layer
data "archive_file" "crawler_lambda_layer" {
  type             = "zip"
  source_dir       = "${path.module}/lambda_build"
  output_path      = "${path.module}/lambda_layer.zip"
  output_file_mode = "0666"
  depends_on       = [null_resource.install_dependencies]
}

# Lambda layer for dependencies
resource "aws_lambda_layer_version" "crawler_dependencies" {
  filename            = data.archive_file.crawler_lambda_layer.output_path
  layer_name          = "${var.environment}-${var.project_name}-crawler-deps"
  compatible_runtimes = ["python3.11"]
  source_code_hash    = data.archive_file.crawler_lambda_layer.output_base64sha256

  depends_on = [data.archive_file.crawler_lambda_layer]
}

# Package Lambda function code (without dependencies)
data "archive_file" "crawler_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_package.zip"
  excludes    = ["requirements.txt", "__pycache__", "*.pyc"]
}

# Lambda function
resource "aws_lambda_function" "crawler" {
  filename         = data.archive_file.crawler_lambda.output_path
  function_name    = "${var.environment}-${var.project_name}-crawler"
  role             = aws_iam_role.crawler_lambda.arn
  handler          = "crawler.lambda_handler"
  source_code_hash = data.archive_file.crawler_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  layers = [
    aws_lambda_layer_version.crawler_dependencies.arn,
    # AWS Data Wrangler layer (includes pandas, pyarrow, boto3, and more)
    # Latest versions: https://aws-sdk-pandas.readthedocs.io/en/stable/layers.html
    "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python311:${var.aws_sdk_pandas_layer_version}"
  ]

  environment {
    variables = {
      DYNAMODB_TABLE_NAME    = aws_dynamodb_table.crawl_state.name
      S3_BUCKET_NAME         = var.data_lake_bucket_name
      GITHUB_TOKEN_ARN       = var.github_token_arn
      REQUESTS_PER_EXECUTION = var.requests_per_execution
      SLEEP_INTERVAL         = var.sleep_interval
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "crawler_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.crawler.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# EventBridge rule to trigger Lambda every 15 minutes
resource "aws_cloudwatch_event_rule" "crawler_schedule" {
  name                = "${var.environment}-${var.project_name}-crawler-schedule"
  description         = "Trigger ${var.project_name} crawler Lambda every 15 minutes"
  schedule_expression = "rate(15 minutes)"

  tags = var.tags
}

# EventBridge target - Lambda function
resource "aws_cloudwatch_event_target" "crawler_lambda" {
  rule      = aws_cloudwatch_event_rule.crawler_schedule.name
  target_id = "CrawlerLambdaTarget"
  arn       = aws_lambda_function.crawler.arn
}

# Lambda permission for EventBridge to invoke
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crawler_schedule.arn
}

# SNS topic for critical alerts
resource "aws_sns_topic" "crawler_alerts" {
  name = "${var.environment}-${var.project_name}-crawler-alerts"

  tags = var.tags
}

# CloudWatch alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "crawler_errors" {
  alarm_name          = "${var.environment}-${var.project_name}-crawler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Alert when crawler Lambda has more than 3 errors in 30 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.crawler.function_name
  }

  alarm_actions = [aws_sns_topic.crawler_alerts.arn]

  tags = var.tags
}

# CloudWatch alarm for Lambda throttling
resource "aws_cloudwatch_metric_alarm" "crawler_throttles" {
  alarm_name          = "${var.environment}-${var.project_name}-crawler-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when crawler Lambda is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.crawler.function_name
  }

  alarm_actions = [aws_sns_topic.crawler_alerts.arn]

  tags = var.tags
}

# Custom CloudWatch metric for crawler progress
resource "aws_cloudwatch_log_metric_filter" "crawler_progress" {
  name           = "${var.environment}-crawler-progress"
  log_group_name = aws_cloudwatch_log_group.crawler_lambda.name
  pattern        = "[time, request_id, level=INFO, msg=\"Crawl complete:\", ...]"

  metric_transformation {
    name      = "CrawlerProgress"
    namespace = "${title(var.project_name)}/ColdPath"
    value     = "1"
    unit      = "Count"
  }
}

# Custom CloudWatch metric for repositories processed
resource "aws_cloudwatch_log_metric_filter" "repositories_processed" {
  name           = "${var.environment}-repositories-processed"
  log_group_name = aws_cloudwatch_log_group.crawler_lambda.name
  pattern        = "[time, request_id, level=INFO, msg=\"Saved\", count, repositories=repositories, ...]"

  metric_transformation {
    name      = "RepositoriesProcessed"
    namespace = "${title(var.project_name)}/ColdPath"
    value     = "$count"
    unit      = "Count"
  }
}

# CloudWatch alarm for stalled crawler (no progress in 30 minutes)
resource "aws_cloudwatch_metric_alarm" "crawler_stalled" {
  alarm_name          = "${var.environment}-${var.project_name}-crawler-stalled"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CrawlerProgress"
  namespace           = "${title(var.project_name)}/ColdPath"
  period              = 900 # 15 minutes
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when crawler has made no progress in 30 minutes"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.crawler_alerts.arn]

  tags = var.tags
}
