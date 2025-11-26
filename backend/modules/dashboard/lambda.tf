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

data "archive_file" "crawler_metrics_resolver_appsync_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/crawler_metrics_resolver.py"
  output_path = "${path.module}/crawler_metrics_resolver_appsync_lambda.zip"
}

# ============================================================================
# IAM Policies for Lambda Functions
# ============================================================================

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





# ============================================================================
# Lambda Functions
# ============================================================================





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

  iam_policy_document  = data.aws_iam_policy_document.crawler_metrics_resolver_appsync_lambda_policy.json
  create_custom_policy = true
  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  environment_variables = {
    DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
    ENVIRONMENT         = var.environment
    PROJECT_NAME        = var.project_name
  }

  tags = var.tags
}
