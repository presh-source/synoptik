# Moved Blocks for Resource Refactoring
# These tell Terraform to move resources in state rather than destroy/recreate

# API Gateway Account: dashboard → dashboard_api module
moved {
  from = module.dashboard.aws_api_gateway_account.dashboard
  to   = module.dashboard.module.dashboard_api.aws_api_gateway_account.api[0]
}

# API Gateway Domain Name: dashboard → dashboard_api module
moved {
  from = module.dashboard.aws_api_gateway_domain_name.dashboard[0]
  to   = module.dashboard.module.dashboard_api.aws_api_gateway_domain_name.api[0]
}

# API Gateway Base Path Mapping: dashboard → dashboard_api module
moved {
  from = module.dashboard.aws_api_gateway_base_path_mapping.dashboard[0]
  to   = module.dashboard.module.dashboard_api.aws_api_gateway_base_path_mapping.api[0]
}

# ACM Certificate: dashboard → api_certificate module
moved {
  from = module.dashboard.aws_acm_certificate.dashboard[0]
  to   = module.dashboard.module.api_certificate[0].aws_acm_certificate.cert[0]
}

# ACM Certificate Validation: dashboard → api_certificate module
moved {
  from = module.dashboard.aws_acm_certificate_validation.dashboard[0]
  to   = module.dashboard.module.api_certificate[0].aws_acm_certificate_validation.cert[0]
}
