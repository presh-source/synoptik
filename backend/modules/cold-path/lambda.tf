# Lambda Resources

# ============================================================================
# Local variables
# ============================================================================

locals {
  runtime                = "python3.11"
  timeout                = 900
  memory_size            = 256
  requests_per_execution = 1200
  sleep_interval         = 0.1
  awssdkpandas_layer     = "arn:aws:lambda:${data.aws_region.current.name}:336392948345:layer:AWSSDKPandas-Python311:23"
  powertools_layer       = "arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPythonV2:68"
}

# ============================================================================
# Lambda Dependencies Layer
# ============================================================================

module "crawler_dependencies" {
  source = "../shared/lambda-layer"

  project_name        = var.project_name
  environment         = var.environment
  layer_name          = "crawler-deps"
  description         = "Shared dependencies for crawler Lambda functions"
  source_path         = "${path.module}/lambda-layer/build"
  build_path          = "${path.module}/lambda-layer/build-output"
  compatible_runtimes = ["python3.11"]
}

# ============================================================================
# Archive Lambda functions
# ============================================================================

data "archive_file" "repo_crawler_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/repo_crawler.py"
  output_path = "${path.module}/repo_lambda_package.zip"
}

data "archive_file" "user_crawler_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/user_crawler.py"
  output_path = "${path.module}/user_lambda_package.zip"
}

data "archive_file" "github_crawler_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/github_crawler.py"
  output_path = "${path.module}/github_lambda_package.zip"
}

data "archive_file" "telemetry_processor_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/telemetry_processor.py"
  output_path = "${path.module}/telemetry_processor_lambda_package.zip"
}

data "archive_file" "telemetry_aggregator_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/telemetry_aggregator.py"
  output_path = "${path.module}/telemetry_aggregator_lambda_package.zip"
}

# ============================================================================
# IAM Policies for Lambda Functions
# ============================================================================

data "aws_iam_policy_document" "repo_crawler_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.crawl_state.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["arn:aws:s3:::${var.data_lake_bucket_name}/cold-path/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "appsync:GraphQL"
    ]
    resources = ["arn:aws:appsync:${data.aws_region.current.name}:*:apis/${var.appsync_api_id}/types/Mutation/fields/publishCrawlerCompleted"]
  }
  statement {
    effect = "Allow"
    actions = [
      "events:PutEvents"
    ]
    resources = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"]
  }
}

data "aws_iam_policy_document" "user_crawler_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.crawl_state.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["arn:aws:s3:::${var.data_lake_bucket_name}/user-path/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "appsync:GraphQL"
    ]
    resources = ["arn:aws:appsync:${data.aws_region.current.name}:*:apis/${var.appsync_api_id}/types/Mutation/fields/publishCrawlerCompleted"]
  }
  statement {
    effect = "Allow"
    actions = [
      "events:PutEvents"
    ]
    resources = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"]
  }
}

data "aws_iam_policy_document" "github_crawler_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.crawl_state.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      "arn:aws:s3:::${var.data_lake_bucket_name}/cold-path/*",
      "arn:aws:s3:::${var.data_lake_bucket_name}/user-path/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "events:PutEvents"
    ]
    resources = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"]
  }
}

data "aws_iam_policy_document" "telemetry_processor_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:Query"
    ]
    resources = [
      aws_dynamodb_table.telemetry.arn,
      "${aws_dynamodb_table.telemetry.arn}/index/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "appsync:GraphQL"
    ]
    resources = ["arn:aws:appsync:${data.aws_region.current.name}:*:apis/${var.appsync_api_id}/types/Mutation/fields/publishCrawlerCompleted"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:FilterLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.data_lake_bucket_name}/cold-path/github/telemetry/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.telemetry_processor_dlq.arn]
  }
}

data "aws_iam_policy_document" "telemetry_aggregator_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query"
    ]
    resources = [
      aws_dynamodb_table.telemetry.arn,
      "${aws_dynamodb_table.telemetry.arn}/index/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
  }
}

# ============================================================================
# Lambda Functions
# ============================================================================

module "repo_crawler" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "repo-crawler"
  function_description = "Crawls GitHub repositories and stores data in S3"
  handler              = "repo_crawler.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.repo_crawler_lambda.output_path
  source_code_hash = data.archive_file.repo_crawler_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.repo_crawler_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.crawler_dependencies.arn,
    local.awssdkpandas_layer,
    local.powertools_layer
  ]

  environment_variables = {
    DYNAMODB_TABLE_NAME       = aws_dynamodb_table.crawl_state.name
    S3_BUCKET_NAME            = var.data_lake_bucket_name
    GITHUB_TOKEN              = var.github_token
    REQUESTS_PER_EXECUTION    = local.requests_per_execution
    SLEEP_INTERVAL            = local.sleep_interval
    PROJECT_NAME              = var.project_name
    DASHBOARD_APPSYNC_API_URL = var.dashboard_appsync_api_url
    SENTRY_DSN                = var.sentry_dsn_backend
    ENVIRONMENT               = var.environment
    VERSION                   = "1.0.0"
  }

  tags = var.tags
}

module "user_crawler" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "user-crawler"
  function_description = "Crawls GitHub users and stores data in S3"
  handler              = "user_crawler.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.user_crawler_lambda.output_path
  source_code_hash = data.archive_file.user_crawler_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.user_crawler_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.crawler_dependencies.arn,
    local.awssdkpandas_layer,
    local.powertools_layer
  ]

  environment_variables = {
    DYNAMODB_TABLE_NAME       = aws_dynamodb_table.crawl_state.name
    S3_BUCKET_NAME            = var.data_lake_bucket_name
    GITHUB_TOKEN              = var.github_token
    REQUESTS_PER_EXECUTION    = local.requests_per_execution
    SLEEP_INTERVAL            = local.sleep_interval
    PROJECT_NAME              = var.project_name
    DASHBOARD_APPSYNC_API_URL = var.dashboard_appsync_api_url
    SENTRY_DSN                = var.sentry_dsn_backend
    ENVIRONMENT               = var.environment
    VERSION                   = "1.0.0"
  }

  tags = var.tags
}

module "github_crawler" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "github-crawler"
  function_description = "Unified GitHub crawler that handles both repos and users"
  handler              = "github_crawler.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.github_crawler_lambda.output_path
  source_code_hash = data.archive_file.github_crawler_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.github_crawler_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    module.crawler_dependencies.arn,
    local.awssdkpandas_layer,
    local.powertools_layer
  ]

  environment_variables = {
    CRAWL_STATE_TABLE_NAME = aws_dynamodb_table.crawl_state.name
    S3_BUCKET_NAME         = var.data_lake_bucket_name
    GITHUB_TOKEN           = var.github_token
    PROJECT_NAME           = var.project_name
    SENTRY_DSN             = var.sentry_dsn_backend
    ENVIRONMENT            = var.environment
    VERSION                = "1.0.0"
  }

  tags = var.tags
}

module "telemetry_processor" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "telemetry-processor"
  function_description = "Processes crawler completion events and stores telemetry data"
  handler              = "telemetry.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.telemetry_processor_lambda.output_path
  source_code_hash = data.archive_file.telemetry_processor_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.telemetry_processor_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    local.awssdkpandas_layer,
    local.powertools_layer,
    module.crawler_dependencies.arn
  ]

  environment_variables = {
    PROJECT_NAME         = var.project_name
    TELEMETRY_TABLE_NAME = aws_dynamodb_table.telemetry.name
    S3_BUCKET_NAME       = var.data_lake_bucket_name
    SENTRY_DSN           = var.sentry_dsn_backend
    ENVIRONMENT          = var.environment
    VERSION              = "1.0.0"
  }

  tags = var.tags
}

module "telemetry_aggregator" {
  source = "../shared/lambda"

  project_name         = var.project_name
  environment          = var.environment
  function_name        = "telemetry-aggregator"
  function_description = "Aggregates crawler telemetry hourly"
  handler              = "telemetry_aggregator.lambda_handler"
  runtime              = local.runtime
  timeout              = local.timeout
  memory_size          = local.memory_size

  filename         = data.archive_file.telemetry_aggregator_lambda.output_path
  source_code_hash = data.archive_file.telemetry_aggregator_lambda.output_base64sha256

  iam_policy_document = data.aws_iam_policy_document.telemetry_aggregator_lambda_policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  layers = [
    local.awssdkpandas_layer,
    local.powertools_layer
  ]

  environment_variables = {
    PROJECT_NAME         = var.project_name
    TELEMETRY_TABLE_NAME = aws_dynamodb_table.telemetry.name
    SENTRY_DSN           = var.sentry_dsn_backend
    ENVIRONMENT          = var.environment
    VERSION              = "1.0.0"
  }

  tags = var.tags
}
