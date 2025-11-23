# ============================================================================
# AppSync GraphQL API
# ============================================================================



resource "aws_appsync_graphql_api" "main" {
  name                = "${var.environment}-${var.project_name}-graphql-api"
  authentication_type = "API_KEY"

  # Additional authentication providers
  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }

  # Schema
  schema = var.schema

  # CloudWatch Logging
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_cloudwatch_logs.arn
    field_log_level          = "ALL"
    exclude_verbose_content  = false
  }

  tags = var.tags
}

# ============================================================================
# API Key
# ============================================================================

resource "aws_appsync_api_key" "main" {
  api_id  = aws_appsync_graphql_api.main.id
  expires = timeadd(timestamp(), "8760h") # 365 days
}

# ============================================================================
# CloudWatch Logs IAM Role
# ============================================================================

resource "aws_iam_role" "appsync_cloudwatch_logs" {
  name = "${var.environment}-${var.project_name}-appsync-cw-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "appsync_cloudwatch_logs" {
  name = "${var.environment}-${var.project_name}-appsync-cw-logs-policy"
  role = aws_iam_role.appsync_cloudwatch_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ============================================================================
# Data Sources
# ============================================================================

resource "aws_appsync_datasource" "datasources" {
  for_each = var.datasources

  api_id           = aws_appsync_graphql_api.main.id
  name             = each.key
  type             = each.value.type
  description      = each.value.description
  service_role_arn = each.value.service_role_arn

  dynamic "lambda_config" {
    for_each = each.value.lambda_config != null ? [each.value.lambda_config] : []
    content {
      function_arn = lambda_config.value.function_arn
    }
  }

  dynamic "dynamodb_config" {
    for_each = each.value.dynamodb_config != null ? [each.value.dynamodb_config] : []
    content {
      table_name = dynamodb_config.value.table_name
      region     = dynamodb_config.value.region
    }
  }

  dynamic "http_config" {
    for_each = each.value.http_config != null ? [each.value.http_config] : []
    content {
      endpoint = http_config.value.endpoint
    }
  }
}

# ============================================================================
# Resolvers
# ============================================================================

resource "aws_appsync_resolver" "resolvers" {
  for_each = var.resolvers

  api_id      = aws_appsync_graphql_api.main.id
  type        = each.value.type
  field       = each.value.field
  data_source = aws_appsync_datasource.datasources[each.value.datasource].name

  request_template  = each.value.request_template
  response_template = each.value.response_template

  dynamic "caching_config" {
    for_each = each.value.caching_config != null ? [each.value.caching_config] : []
    content {
      ttl = caching_config.value.ttl
    }
  }
}

# ============================================================================
# Functions
# ============================================================================

resource "aws_appsync_function" "functions" {
  for_each = var.functions

  api_id      = aws_appsync_graphql_api.main.id
  name        = each.value.name
  data_source = aws_appsync_datasource.datasources[each.value.datasource].name

  request_mapping_template  = each.value.request_template
  response_mapping_template = each.value.response_template
}

# ============================================================================
# Custom Domain
# ============================================================================

resource "aws_appsync_domain_name" "main" {
  count = var.appsync_domain_name != "" ? 1 : 0

  domain_name     = var.appsync_domain_name
  certificate_arn = var.acm_certificate_arn
}

resource "aws_appsync_domain_name_api_association" "main" {
  count = var.appsync_domain_name != "" ? 1 : 0

  api_id      = aws_appsync_graphql_api.main.id
  domain_name = aws_appsync_domain_name.main[0].domain_name
}

module "appsync_dns" {
  count  = var.appsync_domain_name != "" ? 1 : 0
  source = "../certificate-manager"



  project_name     = var.project_name
  certificate_name = "appsync-dns"
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

# ============================================================================
# Secrets Manager
# ============================================================================

resource "aws_secretsmanager_secret" "appsync_api_key" {
  name        = "${var.environment}-${var.project_name}-appsync-api-key"
  description = "AppSync GraphQL API key for frontend authentication"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "appsync_api_key" {
  secret_id = aws_secretsmanager_secret.appsync_api_key.id
  secret_string = jsonencode({
    api_key           = aws_appsync_api_key.main.key
    graphql_endpoint  = aws_appsync_graphql_api.main.uris["GRAPHQL"]
    realtime_endpoint = aws_appsync_graphql_api.main.uris["REALTIME"]
  })
}
