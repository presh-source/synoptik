# Dashboard Module - Lambda Functions

# ============================================================================
# Local variables
# ============================================================================

locals {
  runtime            = "python3.11"
  timeout            = 10
  memory_size        = 512
  awssdkpandas_layer = "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python311:23"
  powertools_layer   = "arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPythonV2:68"
}

# ============================================================================
# Lambda Layer for Dependencies
# ============================================================================

module "dashboard_dependencies" {
  source = "../shared/lambda-layer"

  project_name        = var.project_name
  environment         = var.environment
  layer_name          = "dashboard-deps"
  description         = "Shared dependencies for dashboard Lambda functions"
  source_path         = "${path.module}/lambda-layer/build"
  build_path          = "${path.module}/lambda-layer/build-output"
  compatible_runtimes = ["python3.11"]
}

# ============================================================================
# Archive Lambda functions
# ============================================================================

data "archive_file" "pipeline_status_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/pipeline_status.py"
  output_path = "${path.module}/pipeline_status_lambda.zip"
}

data "archive_file" "cloudwatch_metrics_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/cloudwatch_metrics.py"
  output_path = "${path.module}/cloudwatch_metrics_lambda.zip"
}

data "archive_file" "crawler_metrics_resolver_appsync_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/crawler_metrics_resolver.py"
  output_path = "${path.module}/crawler_metrics_resolver_appsync_lambda.zip"
}

data "archive_file" "error_rates_resolver_appsync_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/error_rates_resolver.py"
  output_path = "${path.module}/error_rates_resolver_appsync_lambda.zip"
}

data "archive_file" "pipeline_status_resolver_appsync_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/pipeline_status_resolver.py"
  output_path = "${path.module}/pipeline_status_resolver_appsync_lambda.zip"
}

data "archive_file" "crawler_stats_resolver_appsync_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/crawler_stats.py"
  output_path = "${path.module}/crawler_stats_resolver_appsync_lambda.zip"
}

# ============================================================================
# IAM Policies for Lambda Functions
# ============================================================================

data "aws_iam_policy_document" "pipeline_status_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.cold_path_dynamodb_table}"]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cloudwatch_metrics_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "lambda:ListFunctions",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "crawler_metrics_resolver_appsync_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.cold_path_dynamodb_table}"]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "error_rates_resolver_appsync_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "pipeline_status_resolver_appsync_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.cold_path_dynamodb_table}"]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "crawler_stats_resolver_appsync_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = [
      var.telemetry_table_arn,
      "${var.telemetry_table_arn}/index/*"
    ]
  }
}

# ============================================================================
# Lambda Functions
# ============================================================================

module "pipeline_status_lambda" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "pipeline-status"
  function_description = "Gathers and returns the overall pipeline status."
  handler              = "pipeline_status.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.pipeline_status_lambda.output_path
  source_code_hash = data.archive_file.pipeline_status_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.pipeline_status_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.dashboard_dependencies.arn,
    local.powertools_layer
  ]

  environment_variables = {
    DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
    ENVIRONMENT         = var.environment
    PROJECT_NAME        = var.project_name
    SENTRY_DSN          = var.sentry_dsn_backend
  }

  tags = var.tags
}

module "cloudwatch_metrics_lambda" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "cloudwatch-metrics"
  function_description = "Gathers and returns CloudWatch metrics."
  handler              = "cloudwatch_metrics.lambda_handler"
  runtime              = "python3.11"
  timeout              = 30
  memory_size          = 512

  filename         = data.archive_file.cloudwatch_metrics_lambda.output_path
  source_code_hash = data.archive_file.cloudwatch_metrics_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.cloudwatch_metrics_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.dashboard_dependencies.arn,
    local.powertools_layer
  ]

  environment_variables = {
    ENVIRONMENT  = var.environment
    PROJECT_NAME = var.project_name
    SENTRY_DSN   = var.sentry_dsn_backend
  }

  tags = var.tags
}

# ----------------------------------------------------------------
# AppSync Resolver Lambdas
# ----------------------------------------------------------------

module "crawler_metrics_resolver_appsync_lambda" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "appsync-crawler-metrics-resolver"
  function_description = "AppSync resolver for crawler metrics."
  handler              = "crawler_metrics_resolver.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.crawler_metrics_resolver_appsync_lambda.output_path
  source_code_hash = data.archive_file.crawler_metrics_resolver_appsync_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.crawler_metrics_resolver_appsync_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  environment_variables = {
    DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
    ENVIRONMENT         = var.environment
    PROJECT_NAME        = var.project_name
  }

  tags = var.tags
}

module "error_rates_resolver_appsync_lambda" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "appsync-error-rates-resolver"
  function_description = "AppSync resolver for error rates."
  handler              = "error_rates_resolver.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.error_rates_resolver_appsync_lambda.output_path
  source_code_hash = data.archive_file.error_rates_resolver_appsync_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.error_rates_resolver_appsync_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  environment_variables = {
    ENVIRONMENT  = var.environment
    PROJECT_NAME = var.project_name
  }

  tags = var.tags
}

module "pipeline_status_resolver_appsync_lambda" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "appsync-pipeline-status-resolver"
  function_description = "AppSync resolver for pipeline status."
  handler              = "pipeline_status_resolver.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.pipeline_status_resolver_appsync_lambda.output_path
  source_code_hash = data.archive_file.pipeline_status_resolver_appsync_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.pipeline_status_resolver_appsync_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.dashboard_dependencies.arn,
    local.powertools_layer
  ]

  environment_variables = {
    DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
    ENVIRONMENT         = var.environment
    PROJECT_NAME        = var.project_name
  }

  tags = var.tags
}

module "crawler_stats_resolver_appsync_lambda" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "appsync-crawler-stats-resolver"
  function_description = "AppSync resolver for crawler stats."
  handler              = "crawler_stats.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.crawler_stats_resolver_appsync_lambda.output_path
  source_code_hash = data.archive_file.crawler_stats_resolver_appsync_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.crawler_stats_resolver_appsync_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.dashboard_dependencies.arn,
    local.powertools_layer
  ]

  environment_variables = {
    TELEMETRY_TABLE_NAME = var.telemetry_table_name
    ENVIRONMENT          = var.environment
    PROJECT_NAME         = var.project_name
  }

  tags = var.tags
}
