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

  project_name        = var.project_name
  environment         = var.environment
  schema              = file("${path.module}/appsync/schema.graphql")
  api_domain_name     = var.api_domain_name
  hosted_zone_name    = var.hosted_zone_name
  acm_certificate_arn = var.api_domain_name != "" ? (var.acm_certificate_arn != "" ? var.acm_certificate_arn : module.frontend_certificate[0].certificate_arn) : ""
  tags                = var.tags

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
    "Mutation.publishCrawlerCompleted" = {
      type              = "Mutation"
      field             = "publishCrawlerCompleted"
      datasource        = "None"
      request_template  = file("${path.module}/appsync/templates/Mutation.publishCrawlerCompleted.req.vtl")
      response_template = file("${path.module}/appsync/templates/Mutation.publishCrawlerCompleted.res.vtl")
    }
    "Subscription.onCrawlerCompleted" = {
      type              = "Subscription"
      field             = "onCrawlerCompleted"
      datasource        = "None"
      request_template  = file("${path.module}/appsync/templates/Subscription.onCrawlerCompleted.req.vtl")
      response_template = file("${path.module}/appsync/templates/Subscription.onCrawlerCompleted.res.vtl")
    }
  }
}
