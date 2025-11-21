# AppSync GraphQL API Resource
# This file contains the AppSync API, data sources, resolvers, and domain configuration

# ============================================================================
# AppSync GraphQL API
# ============================================================================

resource "aws_appsync_graphql_api" "main" {
  name                = "${var.environment}-${var.project_name}-graphql-api"
  authentication_type = "API_KEY"

  # Additional authentication providers
  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }

  # Schema
  schema = file("${path.module}/schema.graphql")

  # CloudWatch Logging
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_cloudwatch_logs.arn
    field_log_level          = "ALL"
    exclude_verbose_content  = false
  }

  tags = var.tags
}

# ============================================================================
# API Key
# ============================================================================

resource "aws_appsync_api_key" "main" {
  api_id  = aws_appsync_graphql_api.main.id
  expires = timeadd(timestamp(), "8760h") # 365 days
}

# ============================================================================
# CloudWatch Logs IAM Role
# ============================================================================

resource "aws_iam_role" "appsync_cloudwatch_logs" {
  name = "${var.environment}-${var.project_name}-appsync-cloudwatch-logs"

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

resource "aws_iam_role_policy" "appsync_cloudwatch_logs" {
  name = "${var.environment}-${var.project_name}-appsync-cloudwatch-logs-policy"
  role = aws_iam_role.appsync_cloudwatch_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# ============================================================================
# Data Sources
# ============================================================================

# Lambda data source for pipeline status resolver
resource "aws_appsync_datasource" "pipeline_status_lambda" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "PipelineStatusLambda"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.pipeline_status_resolver.arn
  }
}

# Lambda data source for crawler metrics resolver
resource "aws_appsync_datasource" "crawler_metrics_lambda" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "CrawlerMetricsLambda"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.crawler_metrics_resolver.arn
  }
}

# Lambda data source for error rates resolver
resource "aws_appsync_datasource" "error_rates_lambda" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "ErrorRatesLambda"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.error_rates_resolver.arn
  }
}

# NONE data source for local mutation resolver
resource "aws_appsync_datasource" "none" {
  api_id = aws_appsync_graphql_api.main.id
  name   = "None"
  type   = "NONE"
}

# ============================================================================
# Resolvers
# ============================================================================

# Query.pipelineStatus resolver
resource "aws_appsync_resolver" "pipeline_status" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "pipelineStatus"
  data_source = aws_appsync_datasource.pipeline_status_lambda.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "pipelineStatus",
    "arguments": $util.toJson($context.arguments)
  }
}
EOF

  response_template = <<EOF
$util.toJson($context.result)
EOF

  caching_config {
    ttl = 30
  }
}

# Query.repoCrawler resolver
resource "aws_appsync_resolver" "repo_crawler" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "repoCrawler"
  data_source = aws_appsync_datasource.crawler_metrics_lambda.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "repoCrawler",
    "crawlerType": "repo",
    "timePeriodHours": $util.defaultIfNull($context.arguments.timePeriodHours, 1)
  }
}
EOF

  response_template = <<EOF
$util.toJson($context.result)
EOF

  caching_config {
    ttl = 30
  }
}

# Query.userCrawler resolver
resource "aws_appsync_resolver" "user_crawler" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "userCrawler"
  data_source = aws_appsync_datasource.crawler_metrics_lambda.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "userCrawler",
    "crawlerType": "user",
    "timePeriodHours": $util.defaultIfNull($context.arguments.timePeriodHours, 1)
  }
}
EOF

  response_template = <<EOF
$util.toJson($context.result)
EOF

  caching_config {
    ttl = 30
  }
}

# Query.errorRates resolver
resource "aws_appsync_resolver" "error_rates" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "errorRates"
  data_source = aws_appsync_datasource.error_rates_lambda.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "errorRates",
    "arguments": $util.toJson($context.arguments)
  }
}
EOF

  response_template = <<EOF
$util.toJson($context.result)
EOF

  caching_config {
    ttl = 30
  }
}

# Mutation.publishCrawlerCompleted resolver (NONE data source)
resource "aws_appsync_resolver" "publish_crawler_completed" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "publishCrawlerCompleted"
  data_source = aws_appsync_datasource.none.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "payload": {
    "crawlerType": "$context.arguments.input.crawlerType",
    "startId": $context.arguments.input.startId,
    "endId": $context.arguments.input.endId,
    "itemsFetched": $context.arguments.input.itemsFetched,
    "totalProcessed": $context.arguments.input.totalProcessed,
    "completedAt": "$util.time.nowISO8601()",
    "success": $context.arguments.input.success,
    "errorMessage": $util.toJson($util.defaultIfNull($context.arguments.input.errorMessage, null))
  }
}
EOF

  response_template = <<EOF
$util.toJson($context.result)
EOF
}

# Subscription.onCrawlerCompleted resolver
resource "aws_appsync_resolver" "on_crawler_completed" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Subscription"
  field       = "onCrawlerCompleted"
  data_source = aws_appsync_datasource.none.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "payload": {}
}
EOF

  response_template = <<EOF
#if($util.isNull($context.arguments.crawlerType))
  $util.toJson($context.result)
#else
  #if($context.result.crawlerType == $context.arguments.crawlerType)
    $util.toJson($context.result)
  #else
    $util.toJson(null)
  #end
#end
EOF
}

# ============================================================================
# API Caching
# ============================================================================

resource "aws_appsync_api_cache" "main" {
  api_id               = aws_appsync_graphql_api.main.id
  api_caching_behavior = "PER_RESOLVER_CACHING"
  type                 = "SMALL"
  ttl                  = 30
}
