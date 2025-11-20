# Dashboard Module - API Gateway Configuration using api-gateway module

# ============================================================================
# Certificate for API (if needed and not provided)
# ============================================================================

module "api_certificate" {
  count  = var.api_domain_name != "" && var.acm_certificate_arn == "" ? 1 : 0
  source = "../domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name       = var.project_name
  certificate_name   = "api"
  domain_name        = var.api_domain_name
  hosted_zone_name   = var.hosted_zone_name
  create_dns_records = false # DNS created separately after API Gateway

  tags = var.tags
}

# ============================================================================
# API Gateway Module
# ============================================================================

module "dashboard_api" {
  source = "../api-gateway"

  project_name    = var.project_name
  environment     = var.environment
  api_name        = "dashboard-api"
  api_description = "Observability Dashboard API for ${var.project_name}"

  # Define API resources (URL paths)
  root_resources = {
    "pipeline-status" = {
      path_part = "pipeline-status"
    }
    "metrics" = {
      path_part = "metrics"
    }
  }

  child_resources = {
    "metrics-cloudwatch" = {
      path_part   = "cloudwatch"
      parent_path = "metrics"
    }
  }

  # Define API methods
  api_methods = {
    "pipeline-status-get" = {
      resource_path      = "pipeline-status"
      http_method        = "GET"
      authorization      = "NONE"
      request_parameters = {}
    }
    "metrics-cloudwatch-get" = {
      resource_path      = "metrics-cloudwatch"
      http_method        = "GET"
      authorization      = "NONE"
      request_parameters = {}
    }
  }

  # Define Lambda integrations
  lambda_integrations = {
    "pipeline-status-get" = {
      resource_path        = "pipeline-status"
      lambda_invoke_arn    = aws_lambda_function.pipeline_status.invoke_arn
      lambda_function_name = aws_lambda_function.pipeline_status.function_name
    }

    "metrics-cloudwatch-get" = {
      resource_path        = "metrics-cloudwatch"
      lambda_invoke_arn    = aws_lambda_function.cloudwatch_metrics.invoke_arn
      lambda_function_name = aws_lambda_function.cloudwatch_metrics.function_name
    }
  }

  # Configuration
  custom_domain_name  = var.api_domain_name
  certificate_arn     = var.api_domain_name != "" ? (var.acm_certificate_arn != "" ? var.acm_certificate_arn : module.api_certificate[0].certificate_arn) : ""
  cloudwatch_role_arn = var.api_gateway_cloudwatch_role_arn
  enable_cors         = true
  enable_xray_tracing = false
  log_retention_days  = 30
  stage_name          = "v1"
  endpoint_type       = "REGIONAL"

  tags = var.tags

  depends_on = [module.api_certificate]
}

# ============================================================================
# DNS for API Domain (after API Gateway is created)
# ============================================================================

module "api_dns" {
  count  = var.api_domain_name != "" ? 1 : 0
  source = "../domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name       = var.project_name
  certificate_name   = "api-dns"
  domain_name        = var.api_domain_name
  hosted_zone_name   = var.hosted_zone_name
  create_certificate = false # Certificate already created above

  # Point to API Gateway custom domain
  target_domain_name = module.dashboard_api.custom_domain_cloudfront_domain_name
  target_zone_id     = module.dashboard_api.custom_domain_cloudfront_zone_id

  enable_ipv6 = true
  tags        = var.tags

  depends_on = [module.dashboard_api]
}
