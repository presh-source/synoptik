# AppSync Domain DNS Configuration

module "appsync_dns" {
  count  = var.appsync_domain_name != "" ? 1 : 0
  source = "../domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = var.project_name
  certificate_name = "graphql-dns"
  domain_name      = var.appsync_domain_name
  hosted_zone_name = var.hosted_zone_name

  # Don't create certificate, only DNS records
  create_certificate = false

  # AppSync domain details
  target_domain_name = aws_appsync_domain_name.main[0].appsync_domain_name
  target_zone_id     = aws_appsync_domain_name.main[0].hosted_zone_id

  enable_ipv6 = false # AppSync doesn't support IPv6
  tags        = var.tags
}
