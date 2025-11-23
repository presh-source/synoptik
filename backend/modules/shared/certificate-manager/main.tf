# Domain and Certificate Module
# Manages Route53 DNS records and ACM certificates



# ============================================================================
# Route53 Hosted Zone (Data Source)
# ============================================================================

data "aws_route53_zone" "main" {
  count        = var.domain_name != "" ? 1 : 0
  name         = var.hosted_zone_name
  private_zone = false
}

# ============================================================================
# ACM Certificate
# ============================================================================

resource "aws_acm_certificate" "cert" {
  count = var.domain_name != "" && var.create_certificate ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names

  validation_method = var.validation_method

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.certificate_name}-cert"
  })
}

# ============================================================================
# DNS Validation Records
# ============================================================================

resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" && var.create_certificate && var.validation_method == "DNS" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
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

# ============================================================================
# Certificate Validation
# ============================================================================

resource "aws_acm_certificate_validation" "cert" {
  count = var.domain_name != "" && var.create_certificate && var.validation_method == "DNS" ? 1 : 0

  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# ============================================================================
# Route53 DNS Records
# ============================================================================

# A record (IPv4)
resource "aws_route53_record" "a" {
  count   = var.domain_name != "" && var.create_dns_records ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.target_domain_name
    zone_id                = var.target_zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}

# AAAA record (IPv6)
resource "aws_route53_record" "aaaa" {
  count   = var.domain_name != "" && var.create_dns_records && var.enable_ipv6 ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.target_domain_name
    zone_id                = var.target_zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}

# CNAME record (alternative to alias)
resource "aws_route53_record" "cname" {
  count   = var.domain_name != "" && var.create_dns_records && var.use_cname ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = var.cname_ttl
  records = [var.target_domain_name]
}
