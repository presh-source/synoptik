# ACM Certificate for custom domain
# Note: CloudFront requires certificates to be in us-east-1 region

data "aws_route53_zone" "main" {
  count        = var.domain_name != "" || var.api_domain_name != "" ? 1 : 0
  name         = replace(coalesce(var.domain_name, var.api_domain_name), "/^[^.]+\\./", "") # Extract root domain
  private_zone = false
}

resource "aws_acm_certificate" "dashboard" {
  count             = (var.domain_name != "" || var.api_domain_name != "") && var.acm_certificate_arn == "" ? 1 : 0
  domain_name       = var.domain_name != "" ? var.domain_name : var.api_domain_name
  subject_alternative_names = var.domain_name != "" && var.api_domain_name != "" ? [
    var.api_domain_name
  ] : []
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-dashboard-cert"
  })
}

# DNS validation records for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = (var.domain_name != "" || var.api_domain_name != "") && var.acm_certificate_arn == "" ? {
    for dvo in aws_acm_certificate.dashboard[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "dashboard" {
  count                   = (var.domain_name != "" || var.api_domain_name != "") && var.acm_certificate_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.dashboard[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
