# Domain and Certificate Module - Outputs

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.create_certificate && var.domain_name != "" ? aws_acm_certificate.cert[0].arn : null
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = var.create_certificate && var.domain_name != "" ? aws_acm_certificate.cert[0].domain_name : null
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = var.create_certificate && var.domain_name != "" ? aws_acm_certificate.cert[0].status : null
}

output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = var.domain_name != "" ? data.aws_route53_zone.main[0].zone_id : null
}

output "hosted_zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = var.domain_name != "" ? data.aws_route53_zone.main[0].name : null
}

output "dns_record_name" {
  description = "Name of the created DNS record"
  value       = var.domain_name != "" && var.create_dns_records ? var.domain_name : null
}

output "dns_record_fqdn" {
  description = "FQDN of the created DNS record"
  value = var.domain_name != "" && var.create_dns_records ? (
    var.use_cname ? (
      length(aws_route53_record.cname) > 0 ? aws_route53_record.cname[0].fqdn : null
    ) : (
      length(aws_route53_record.a) > 0 ? aws_route53_record.a[0].fqdn : null
    )
  ) : null
}

output "validation_record_fqdns" {
  description = "FQDNs of the certificate validation records"
  value       = var.create_certificate && var.domain_name != "" && var.validation_method == "DNS" ? [for record in aws_route53_record.cert_validation : record.fqdn] : []
}
