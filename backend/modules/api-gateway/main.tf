# API Gateway Module
# Manages REST API Gateway configuration

# ============================================================================
# API Gateway REST API
# ============================================================================

resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.environment}-${var.project_name}-${var.api_name}"
  description = var.api_description

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = var.tags
}

# ============================================================================
# API Gateway Resources (URL paths)
# ============================================================================

resource "aws_api_gateway_resource" "root_resources" {
  for_each = var.root_resources

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "child_resources" {
  for_each = var.child_resources

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.root_resources[each.value.parent_path].id
  path_part   = each.value.path_part
}

locals {
  all_resources = merge(
    aws_api_gateway_resource.root_resources,
    aws_api_gateway_resource.child_resources
  )
}

# ============================================================================
# API Gateway Methods
# ============================================================================

resource "aws_api_gateway_method" "methods" {
  for_each = var.api_methods

  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = local.all_resources[each.value.resource_path].id
  http_method   = each.value.http_method
  authorization = each.value.authorization

  request_parameters = each.value.request_parameters
}

# ============================================================================
# Lambda Integrations
# ============================================================================

resource "aws_api_gateway_integration" "lambda_integrations" {
  for_each = var.lambda_integrations

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = local.all_resources[each.value.resource_path].id
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_invoke_arn
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  for_each = var.lambda_integrations

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# ============================================================================
# CORS Configuration
# ============================================================================

resource "aws_api_gateway_method" "options" {
  for_each = var.enable_cors ? local.all_resources : {}

  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = var.enable_cors ? local.all_resources : {}

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = var.enable_cors ? local.all_resources : {}

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = var.enable_cors ? local.all_resources : {}

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = aws_api_gateway_method_response.options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ============================================================================
# API Gateway Deployment
# ============================================================================

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.api.body,
      local.all_resources,
      aws_api_gateway_method.methods,
      aws_api_gateway_integration.lambda_integrations,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.methods,
    aws_api_gateway_integration.lambda_integrations,
  ]
}

# ============================================================================
# API Gateway Stage
# ============================================================================

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = var.enable_xray_tracing

  tags = var.tags
}

# ============================================================================
# CloudWatch Logs
# ============================================================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}-${var.project_name}-${var.api_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ============================================================================
# API Gateway Account (for CloudWatch logging)
# ============================================================================

resource "aws_api_gateway_account" "api" {
  count               = var.cloudwatch_role_arn != "" ? 1 : 0
  cloudwatch_role_arn = var.cloudwatch_role_arn
  reset_on_delete     = true
}

# ============================================================================
# Custom Domain Name (if provided)
# ============================================================================

resource "aws_api_gateway_domain_name" "api" {
  count           = var.custom_domain_name != "" ? 1 : 0
  domain_name     = var.custom_domain_name
  certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = var.tags
}

resource "aws_api_gateway_base_path_mapping" "api" {
  count       = var.custom_domain_name != "" ? 1 : 0
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api.stage_name
  domain_name = aws_api_gateway_domain_name.api[0].domain_name
  base_path   = var.base_path
}
