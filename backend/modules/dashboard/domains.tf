# Dashboard Module - Domain and Certificate Configuration

# ============================================================================
# Frontend Certificate (created first, without DNS)
# ============================================================================

module "frontend_certificate" {
  count  = var.frontend_domain_name != "" && var.acm_certificate_arn == "" ? 1 : 0
  source = "../shared/certificate-manager"



  project_name     = var.project_name
  certificate_name = "frontend"
  domain_name      = var.frontend_domain_name
  hosted_zone_name = var.hosted_zone_name

  # Include API domain as SAN if both are provided
  subject_alternative_names = compact(concat(
    var.api_domain_name != "" ? [var.api_domain_name] : [],
    var.appsync_domain_name != "" ? [var.appsync_domain_name] : []
  ))

  # Create certificate only, DNS records created later
  create_dns_records = false

  tags = var.tags
}

# ============================================================================
# Frontend DNS Records (created after CloudFront)
# ============================================================================

module "frontend_dns" {
  count  = var.frontend_domain_name != "" ? 1 : 0
  source = "../shared/certificate-manager"

  project_name     = var.project_name
  certificate_name = "frontend"
  domain_name      = var.frontend_domain_name
  hosted_zone_name = var.hosted_zone_name

  # Don't create certificate, only DNS records
  create_certificate = false

  # CloudFront distribution details
  target_domain_name = aws_cloudfront_distribution.dashboard.domain_name
  target_zone_id     = aws_cloudfront_distribution.dashboard.hosted_zone_id

  enable_ipv6 = true
  tags        = var.tags

  depends_on = [aws_cloudfront_distribution.dashboard]
}

# ============================================================================
# DNS for API Domain (after API Gateway is created)
# ============================================================================

module "api_gateway_dns" {
  count  = var.api_domain_name != "" ? 1 : 0
  source = "../shared/certificate-manager"

  project_name       = var.project_name
  certificate_name   = "api-${var.environment}-${var.project_name}"
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
