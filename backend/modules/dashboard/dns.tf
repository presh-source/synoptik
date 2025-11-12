# Route53 DNS records for custom domains

# Frontend domain (CloudFront)
resource "aws_route53_record" "dashboard" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.dashboard[0].domain_name
    zone_id                = aws_cloudfront_distribution.dashboard[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 record for frontend CloudFront
resource "aws_route53_record" "dashboard_ipv6" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.dashboard[0].domain_name
    zone_id                = aws_cloudfront_distribution.dashboard[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# API domain (API Gateway)
resource "aws_route53_record" "dashboard_api" {
  count   = var.api_domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.dashboard[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.dashboard[0].cloudfront_zone_id
    evaluate_target_health = false
  }
}

# IPv6 record for API Gateway
resource "aws_route53_record" "dashboard_api_ipv6" {
  count   = var.api_domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.api_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_api_gateway_domain_name.dashboard[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.dashboard[0].cloudfront_zone_id
    evaluate_target_health = false
  }
}
