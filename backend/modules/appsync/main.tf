# AppSync Module - Lambda Data Sources for GraphQL Resolvers
# This module creates Lambda functions that serve as data sources for AppSync resolvers

# Get current AWS region
data "aws_region" "current" {}

# ============================================================================
# IAM Roles for Lambda Functions
# ============================================================================

# IAM role for pipeline status resolver Lambda
resource "aws_iam_role" "pipeline_status_resolver_lambda" {
  name = "${var.environment}-${var.project_name}-appsync-pipeline-status-resolver"

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
resource "aws_iam_role_policy_attachment" "pipeline_status_resolver_lambda_basic" {
  role       = aws_iam_role.pipeline_status_resolver_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for pipeline status resolver Lambda
resource "aws_iam_role_policy" "pipeline_status_resolver_lambda_policy" {
  name = "${var.environment}-${var.project_name}-appsync-pipeline-status-resolver-policy"
  role = aws_iam_role.pipeline_status_resolver_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.cold_path_dynamodb_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for crawler metrics resolver Lambda
resource "aws_iam_role" "crawler_metrics_resolver_lambda" {
  name = "${var.environment}-${var.project_name}-appsync-crawler-metrics-resolver"

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
resource "aws_iam_role_policy_attachment" "crawler_metrics_resolver_lambda_basic" {
  role       = aws_iam_role.crawler_metrics_resolver_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for crawler metrics resolver Lambda
resource "aws_iam_role_policy" "crawler_metrics_resolver_lambda_policy" {
  name = "${var.environment}-${var.project_name}-appsync-crawler-metrics-resolver-policy"
  role = aws_iam_role.crawler_metrics_resolver_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.cold_path_dynamodb_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for error rates resolver Lambda
resource "aws_iam_role" "error_rates_resolver_lambda" {
  name = "${var.environment}-${var.project_name}-appsync-error-rates-resolver"

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
resource "aws_iam_role_policy_attachment" "error_rates_resolver_lambda_basic" {
  role       = aws_iam_role.error_rates_resolver_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for error rates resolver Lambda
resource "aws_iam_role_policy" "error_rates_resolver_lambda_policy" {
  name = "${var.environment}-${var.project_name}-appsync-error-rates-resolver-policy"
  role = aws_iam_role.error_rates_resolver_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Lambda Functions
# ============================================================================

# Archive Lambda functions
data "archive_file" "pipeline_status_resolver_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/pipeline_status_resolver_lambda.zip"
  excludes    = ["crawler_metrics_resolver.py", "error_rates_resolver.py", "__pycache__", "*.pyc"]
}

data "archive_file" "crawler_metrics_resolver_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/crawler_metrics_resolver_lambda.zip"
  excludes    = ["pipeline_status_resolver.py", "error_rates_resolver.py", "__pycache__", "*.pyc"]
}

data "archive_file" "error_rates_resolver_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/error_rates_resolver_lambda.zip"
  excludes    = ["pipeline_status_resolver.py", "crawler_metrics_resolver.py", "__pycache__", "*.pyc"]
}

# Pipeline Status Resolver Lambda
resource "aws_lambda_function" "pipeline_status_resolver" {
  filename         = data.archive_file.pipeline_status_resolver_lambda.output_path
  function_name    = "${var.environment}-${var.project_name}-appsync-pipeline-status-resolver"
  role             = aws_iam_role.pipeline_status_resolver_lambda.arn
  handler          = "pipeline_status_resolver.lambda_handler"
  source_code_hash = data.archive_file.pipeline_status_resolver_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
      ENVIRONMENT         = var.environment
      PROJECT_NAME        = var.project_name
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for pipeline status resolver Lambda
resource "aws_cloudwatch_log_group" "pipeline_status_resolver_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.pipeline_status_resolver.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# Crawler Metrics Resolver Lambda
resource "aws_lambda_function" "crawler_metrics_resolver" {
  filename         = data.archive_file.crawler_metrics_resolver_lambda.output_path
  function_name    = "${var.environment}-${var.project_name}-appsync-crawler-metrics-resolver"
  role             = aws_iam_role.crawler_metrics_resolver_lambda.arn
  handler          = "crawler_metrics_resolver.lambda_handler"
  source_code_hash = data.archive_file.crawler_metrics_resolver_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
      ENVIRONMENT         = var.environment
      PROJECT_NAME        = var.project_name
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for crawler metrics resolver Lambda
resource "aws_cloudwatch_log_group" "crawler_metrics_resolver_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.crawler_metrics_resolver.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# Error Rates Resolver Lambda
resource "aws_lambda_function" "error_rates_resolver" {
  filename         = data.archive_file.error_rates_resolver_lambda.output_path
  function_name    = "${var.environment}-${var.project_name}-appsync-error-rates-resolver"
  role             = aws_iam_role.error_rates_resolver_lambda.arn
  handler          = "error_rates_resolver.lambda_handler"
  source_code_hash = data.archive_file.error_rates_resolver_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for error rates resolver Lambda
resource "aws_cloudwatch_log_group" "error_rates_resolver_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.error_rates_resolver.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# ============================================================================
# AppSync IAM Role - Grant AppSync permission to invoke Lambda functions
# ============================================================================

# IAM role for AppSync to invoke Lambda functions
# This role follows the principle of least privilege by:
# - Only allowing AppSync service to assume the role
# - Restricting Lambda invocation to specific resolver functions
resource "aws_iam_role" "appsync_lambda_role" {
  name = "${var.environment}-${var.project_name}-appsync-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for AppSync to invoke Lambda functions
# Follows principle of least privilege by:
# - Only granting lambda:InvokeFunction (not broader permissions)
# - Specifying exact Lambda function ARNs (no wildcards)
# - Restricting to resolver Lambda functions only
resource "aws_iam_role_policy" "appsync_lambda_policy" {
  name = "${var.environment}-${var.project_name}-appsync-lambda-policy"
  role = aws_iam_role.appsync_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.pipeline_status_resolver.arn,
          aws_lambda_function.crawler_metrics_resolver.arn,
          aws_lambda_function.error_rates_resolver.arn
        ]
      }
    ]
  })
}

# ============================================================================
# Lambda Permissions - Allow AppSync to invoke Lambda functions
# ============================================================================
# These permissions follow the principle of least privilege by:
# - Using source_arn to restrict invocations to a specific AppSync API
# - Only granting lambda:InvokeFunction permission
# - Applied per-function (not using wildcards)

# Permission for AppSync to invoke pipeline status resolver Lambda
resource "aws_lambda_permission" "appsync_invoke_pipeline_status_resolver" {
  statement_id  = "AllowAppSyncInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_status_resolver.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = "${aws_appsync_graphql_api.main.arn}/*"
}

# Permission for AppSync to invoke crawler metrics resolver Lambda
resource "aws_lambda_permission" "appsync_invoke_crawler_metrics_resolver" {
  statement_id  = "AllowAppSyncInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crawler_metrics_resolver.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = "${aws_appsync_graphql_api.main.arn}/*"
}

# Permission for AppSync to invoke error rates resolver Lambda
resource "aws_lambda_permission" "appsync_invoke_error_rates_resolver" {
  statement_id  = "AllowAppSyncInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.error_rates_resolver.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = "${aws_appsync_graphql_api.main.arn}/*"
}
