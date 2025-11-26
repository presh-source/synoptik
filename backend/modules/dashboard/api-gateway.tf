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

    "metrics" = {
      path_part = "metrics"
    }
  }

  child_resources = {

  }

  # Define API methods
  api_methods = {


  }

  # Define Lambda integrations
  lambda_integrations = {



  }

  # Configuration - only use custom domain if we have a certificate
  domain_name         = var.api_gateway_domain_name != "" ? var.api_gateway_domain_name : ""
  certificate_arn     = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (length(module.frontend_certificate) > 0 ? module.frontend_certificate[0].certificate_arn : null)
  cloudwatch_role_arn = var.api_gateway_cloudwatch_role_arn
  enable_cors         = true
  enable_xray_tracing = false
  log_retention_days  = 30
  stage_name          = "v1"
  endpoint_type       = "EDGE"

  tags = var.tags


