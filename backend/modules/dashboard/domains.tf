# Dashboard Module - Domain and Certificate Configuration

# ============================================================================
# Frontend Certificate (created first, without DNS)
# ============================================================================

module "frontend_certificate" {
  count  = var.domain_name != "" && var.acm_certificate_arn == "" ? 1 : 0
  source = "../domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = var.project_name
  certificate_name = "frontend"
  domain_name      = var.domain_name

  # Include API domain as SAN if both are provided
  subject_alternative_names = var.api_domain_name != "" ? [var.api_domain_name] : []

  # Create certificate only, DNS records created later
  create_dns_records = false

  tags = var.tags
}

# ============================================================================
# Frontend DNS Records (created after CloudFront)
# ============================================================================

module "frontend_dns" {
  count  = var.domain_name != "" ? 1 : 0
  source = "../domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = var.project_name
  certificate_name = "frontend-dns"
  domain_name      = var.domain_name

  # Don't create certificate, only DNS records
  create_certificate = false

  # CloudFront distribution details
  target_domain_name = aws_cloudfront_distribution.dashboard.domain_name
  target_zone_id     = aws_cloudfront_distribution.dashboard.hosted_zone_id

  enable_ipv6 = true
  tags        = var.tags

  depends_on = [aws_cloudfront_distribution.dashboard]
}
