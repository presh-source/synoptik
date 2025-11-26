# Dashboard Module - AppSync

resource "aws_iam_role_policy" "appsync_lambda_invocation" {
  name = "${var.environment}-${var.project_name}-appsync-lambda-invocation"
  role = split("/", var.appsync_lambda_invocation_role_arn)[1]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "lambda:InvokeFunction"
        Effect = "Allow"
        Resource = [
          module.crawler_metrics_resolver_appsync_lambda.function_arn,

        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "appsync_dynamodb_access" {
  name = "${var.environment}-${var.project_name}-appsync-dynamodb-access"
  role = split("/", var.appsync_lambda_invocation_role_arn)[1]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          var.telemetry_table_arn,
          "${var.telemetry_table_arn}/index/*"
        ]
      }
    ]
  })
}

# ============================================================================
# AppSync GraphQL API
# ============================================================================

module "appsync" {
  source = "../shared/appsync"

  project_name = var.project_name
  environment  = var.environment
  schema       = file("${path.module}/appsync/schema.graphql")
  tags         = var.tags

  datasources = {

    CrawlerMetricsLambda = {
      type             = "AWS_LAMBDA"
      service_role_arn = var.appsync_lambda_invocation_role_arn
      lambda_config = {
        function_arn = module.crawler_metrics_resolver_appsync_lambda.function_arn
      }
    }

    TelemetryTable = {
      type             = "AMAZON_DYNAMODB"
      service_role_arn = var.appsync_lambda_invocation_role_arn
      dynamodb_config = {
        table_name = var.telemetry_table_name
        region     = data.aws_region.current.name
      }
    }
    None = {
      type = "NONE"
    }
  }

  resolvers = {
    "Query.getCrawlerState" = {
      type              = "Query"
      field             = "getCrawlerState"
      datasource        = "TelemetryTable"
      request_template  = file("${path.module}/appsync/templates/Query.getCrawlerState.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.getCrawlerState.res.vtl")
    }
    "Mutation.publishCrawlerCompleted" = {
      type              = "Mutation"
      field             = "publishCrawlerCompleted"
      datasource        = "None"
      request_template  = file("${path.module}/appsync/templates/Mutation.publishCrawlerCompleted.req.vtl")
      response_template = file("${path.module}/appsync/templates/Mutation.publishCrawlerCompleted.res.vtl")
    }
  }
}
