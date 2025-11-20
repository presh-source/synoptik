# Dashboard Module - Lambda Functions and IAM Roles
# API Gateway configuration moved to api.tf (using api-gateway module)
# Domain/Certificate configuration moved to domains.tf (using domain-certificate module)

# Get current AWS region
data "aws_region" "current" {}

# ============================================================================
# IAM Roles for Lambda Functions
# ============================================================================

# IAM role for pipeline status Lambda
resource "aws_iam_role" "pipeline_status_lambda" {
  name = "${var.environment}-${var.project_name}-pipeline-status-lambda"

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
resource "aws_iam_role_policy_attachment" "pipeline_status_lambda_basic" {
  role       = aws_iam_role.pipeline_status_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for pipeline status Lambda
resource "aws_iam_role_policy" "pipeline_status_lambda_policy" {
  name = "${var.environment}-${var.project_name}-pipeline-status-lambda-policy"
  role = aws_iam_role.pipeline_status_lambda.id

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

# IAM role for CloudWatch metrics Lambda
resource "aws_iam_role" "cloudwatch_metrics_lambda" {
  name = "${var.environment}-${var.project_name}-cloudwatch-metrics-lambda"

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
resource "aws_iam_role_policy_attachment" "cloudwatch_metrics_lambda_basic" {
  role       = aws_iam_role.cloudwatch_metrics_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for CloudWatch metrics Lambda
resource "aws_iam_role_policy" "cloudwatch_metrics_lambda_policy" {
  name = "${var.environment}-${var.project_name}-cloudwatch-metrics-lambda-policy"
  role = aws_iam_role.cloudwatch_metrics_lambda.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:ListFunctions"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Lambda Layer for Dependencies
# ============================================================================

# Install Lambda dependencies locally using an external data source to ensure it runs before archiving
data "external" "pip_install" {
  program = ["/bin/bash", "${path.module}/lambda_deps_build/install_deps.sh", "${path.module}/lambda_deps_build"]

  # Re-run when requirements.txt changes
  query = {
    requirements_md5 = filemd5("${path.module}/lambda_deps_build/requirements.txt")
  }
}

# Package Lambda dependencies as a layer
data "archive_file" "dashboard_lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_deps_build/python"
  output_path = "${path.module}/lambda_layer.zip"

  # This creates the dependency: archive runs after pip_install completes
  depends_on = [data.external.pip_install]
}

# Lambda layer for shared dependencies
resource "aws_lambda_layer_version" "dashboard_dependencies" {
  filename            = data.archive_file.dashboard_lambda_layer.output_path
  layer_name          = "${var.environment}-${var.project_name}-dashboard-deps"
  compatible_runtimes = ["python3.11"]
  source_code_hash    = data.archive_file.dashboard_lambda_layer.output_base64sha256
  description         = "Shared dependencies for dashboard Lambda functions"

  depends_on = [data.archive_file.dashboard_lambda_layer]
}

# ============================================================================
# Lambda Functions
# ============================================================================

# Archive Lambda functions
data "archive_file" "pipeline_status_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/pipeline_status_lambda.zip"
  excludes    = ["cloudwatch_metrics.py", "requirements.txt", "__pycache__", "*.pyc"]
}

data "archive_file" "cloudwatch_metrics_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/cloudwatch_metrics_lambda.zip"
  excludes    = ["pipeline_status.py", "requirements.txt", "__pycache__", "*.pyc"]
}

# Pipeline Status Lambda
resource "aws_lambda_function" "pipeline_status" {
  filename         = data.archive_file.pipeline_status_lambda.output_path
  function_name    = "${var.environment}-${var.project_name}-pipeline-status"
  role             = aws_iam_role.pipeline_status_lambda.arn
  handler          = "pipeline_status.lambda_handler"
  source_code_hash = data.archive_file.pipeline_status_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  layers = [
    aws_lambda_layer_version.dashboard_dependencies.arn,
    "arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPythonV2:68"
  ]

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
      ENVIRONMENT         = var.environment
      PROJECT_NAME        = var.project_name
      SENTRY_DSN          = var.sentry_dsn_backend
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for pipeline status Lambda
resource "aws_cloudwatch_log_group" "pipeline_status_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.pipeline_status.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Metrics Lambda
resource "aws_lambda_function" "cloudwatch_metrics" {
  filename         = data.archive_file.cloudwatch_metrics_lambda.output_path
  function_name    = "${var.environment}-${var.project_name}-cloudwatch-metrics"
  role             = aws_iam_role.cloudwatch_metrics_lambda.arn
  handler          = "cloudwatch_metrics.lambda_handler"
  source_code_hash = data.archive_file.cloudwatch_metrics_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 512
  layers = [
    aws_lambda_layer_version.dashboard_dependencies.arn,
    "arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPythonV2:68"
  ]

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      PROJECT_NAME = var.project_name
      SENTRY_DSN   = var.sentry_dsn_backend
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for CloudWatch metrics Lambda
resource "aws_cloudwatch_log_group" "cloudwatch_metrics_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.cloudwatch_metrics.function_name}"
  retention_in_days = 30

  tags = var.tags
}
