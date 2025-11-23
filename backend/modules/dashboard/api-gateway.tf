# Dashboard Module - API Gateway Configuration using api-gateway module

# ============================================================================
# API Gateway Module
# ============================================================================

module "dashboard_api" {
  source = "../shared/api-gateway"

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
      lambda_invoke_arn    = module.pipeline_status_lambda.invoke_arn
      lambda_function_name = module.pipeline_status_lambda.function_name
    }

    "metrics-cloudwatch-get" = {
      resource_path        = "metrics-cloudwatch"
      lambda_invoke_arn    = module.cloudwatch_metrics_lambda.invoke_arn
      lambda_function_name = module.cloudwatch_metrics_lambda.function_name
    }
  }

  # Configuration - only use custom domain if we have a certificate
  domain_name         = var.api_gateway_domain_name != "" && (var.acm_certificate_arn != "" || length(module.frontend_certificate) > 0) ? var.api_gateway_domain_name : ""
  certificate_arn     = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (length(module.frontend_certificate) > 0 ? module.frontend_certificate[0].certificate_arn : null)
  cloudwatch_role_arn = var.api_gateway_cloudwatch_role_arn
  enable_cors         = true
  enable_xray_tracing = false
  log_retention_days  = 30
  stage_name          = "v1"
  endpoint_type       = "EDGE"

  tags = var.tags

  depends_on = [module.frontend_certificate]
}
