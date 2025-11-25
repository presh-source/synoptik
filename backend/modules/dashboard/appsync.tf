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
          module.pipeline_status_resolver_appsync_lambda.function_arn,
          module.crawler_metrics_resolver_appsync_lambda.function_arn,
          module.error_rates_resolver_appsync_lambda.function_arn,
          module.crawler_stats_resolver_appsync_lambda.function_arn,
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
    PipelineStatusLambda = {
      type             = "AWS_LAMBDA"
      service_role_arn = var.appsync_lambda_invocation_role_arn
      lambda_config = {
        function_arn = module.pipeline_status_resolver_appsync_lambda.function_arn
      }
    }
    CrawlerMetricsLambda = {
      type             = "AWS_LAMBDA"
      service_role_arn = var.appsync_lambda_invocation_role_arn
      lambda_config = {
        function_arn = module.crawler_metrics_resolver_appsync_lambda.function_arn
      }
    }
    ErrorRatesLambda = {
      type             = "AWS_LAMBDA"
      service_role_arn = var.appsync_lambda_invocation_role_arn
      lambda_config = {
        function_arn = module.error_rates_resolver_appsync_lambda.function_arn
      }
    }
    CrawlerStatsLambda = {
      type             = "AWS_LAMBDA"
      service_role_arn = var.appsync_lambda_invocation_role_arn
      lambda_config = {
        function_arn = module.crawler_stats_resolver_appsync_lambda.function_arn
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
    "Query.pipelineStatus" = {
      type              = "Query"
      field             = "pipelineStatus"
      datasource        = "PipelineStatusLambda"
      request_template  = file("${path.module}/appsync/templates/Query.pipelineStatus.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.pipelineStatus.res.vtl")
      caching_config    = { ttl = 30 }
    }
    "Query.repoCrawler" = {
      type              = "Query"
      field             = "repoCrawler"
      datasource        = "CrawlerMetricsLambda"
      request_template  = file("${path.module}/appsync/templates/Query.repoCrawler.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.repoCrawler.res.vtl")
      caching_config    = { ttl = 30 }
    }
    "Query.userCrawler" = {
      type              = "Query"
      field             = "userCrawler"
      datasource        = "CrawlerMetricsLambda"
      request_template  = file("${path.module}/appsync/templates/Query.userCrawler.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.userCrawler.res.vtl")
      caching_config    = { ttl = 30 }
    }
    "Query.errorRates" = {
      type              = "Query"
      field             = "errorRates"
      datasource        = "ErrorRatesLambda"
      request_template  = file("${path.module}/appsync/templates/Query.errorRates.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.errorRates.res.vtl")
      caching_config    = { ttl = 30 }
    }
    "Query.getBookmark" = {
      type              = "Query"
      field             = "getBookmark"
      datasource        = "TelemetryTable"
      request_template  = file("${path.module}/appsync/templates/Query.getBookmark.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.getBookmark.res.vtl")
    }
    "Query.listRunsByType" = {
      type              = "Query"
      field             = "listRunsByType"
      datasource        = "TelemetryTable"
      request_template  = file("${path.module}/appsync/templates/Query.listRunsByType.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.listRunsByType.res.vtl")
    }
    "Query.getRunRequests" = {
      type              = "Query"
      field             = "getRunRequests"
      datasource        = "TelemetryTable"
      request_template  = file("${path.module}/appsync/templates/Query.getRunRequests.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.getRunRequests.res.vtl")
    }
    "Query.listHourlyAggregations" = {
      type              = "Query"
      field             = "listHourlyAggregations"
      datasource        = "TelemetryTable"
      request_template  = file("${path.module}/appsync/templates/Query.listHourlyAggregations.req.vtl")
      response_template = file("${path.module}/appsync/templates/Query.listHourlyAggregations.res.vtl")
    }
    "Query.getCrawlerStats" = {
      type              = "Query"
      field             = "getCrawlerStats"
      datasource        = "CrawlerStatsLambda"
      request_template  = "{ \"version\": \"2017-02-28\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context.arguments) }"
      response_template = "$util.toJson($context.result)"
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
