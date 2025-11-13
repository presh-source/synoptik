# Dashboard Module - Observability Dashboard Backend API

# ============================================================================
# API Gateway REST API
# ============================================================================

resource "aws_api_gateway_rest_api" "dashboard" {
  name        = "${var.environment}-${var.project_name}-dashboard-api"
  description = "Observability Dashboard API for ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# ============================================================================
# API Gateway Resources (URL paths)
# ============================================================================

# /api resource
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  parent_id   = aws_api_gateway_rest_api.dashboard.root_resource_id
  path_part   = "api"
}

# /api/pipeline-status resource
resource "aws_api_gateway_resource" "pipeline_status" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "pipeline-status"
}

# /api/metrics resource
resource "aws_api_gateway_resource" "metrics" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "metrics"
}

# /api/metrics/realtime resource
resource "aws_api_gateway_resource" "metrics_realtime" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  parent_id   = aws_api_gateway_resource.metrics.id
  path_part   = "realtime"
}

# /api/metrics/trending resource
resource "aws_api_gateway_resource" "metrics_trending" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  parent_id   = aws_api_gateway_resource.metrics.id
  path_part   = "trending"
}

# /api/metrics/cloudwatch resource
resource "aws_api_gateway_resource" "metrics_cloudwatch" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  parent_id   = aws_api_gateway_resource.metrics.id
  path_part   = "cloudwatch"
}

# ============================================================================
# IAM Roles for Lambda Functions
# ============================================================================

# IAM role for pipeline status Lambda
resource "aws_iam_role" "pipeline_status_lambda" {
  name = "${var.environment}-${var.project_name}-pipeline-status-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "pipeline_status_lambda_basic" {
  role       = aws_iam_role.pipeline_status_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for pipeline status Lambda
resource "aws_iam_role_policy" "pipeline_status_lambda_policy" {
  name = "${var.environment}-${var.project_name}-pipeline-status-lambda-policy"
  role = aws_iam_role.pipeline_status_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.cold_path_dynamodb_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards"
        ]
        Resource = "arn:aws:kinesis:*:*:stream/${var.kinesis_stream_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for realtime metrics Lambda
resource "aws_iam_role" "realtime_metrics_lambda" {
  name = "${var.environment}-${var.project_name}-realtime-metrics-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "realtime_metrics_lambda_basic" {
  role       = aws_iam_role.realtime_metrics_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for realtime metrics Lambda (OpenSearch access)
resource "aws_iam_role_policy" "realtime_metrics_lambda_policy" {
  name = "${var.environment}-${var.project_name}-realtime-metrics-lambda-policy"
  role = aws_iam_role.realtime_metrics_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost"
        ]
        Resource = "arn:aws:es:*:*:domain/*"
      }
    ]
  })
}

# IAM role for CloudWatch metrics Lambda
resource "aws_iam_role" "cloudwatch_metrics_lambda" {
  name = "${var.environment}-${var.project_name}-cloudwatch-metrics-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "cloudwatch_metrics_lambda_basic" {
  role       = aws_iam_role.cloudwatch_metrics_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for CloudWatch metrics Lambda
resource "aws_iam_role_policy" "cloudwatch_metrics_lambda_policy" {
  name = "${var.environment}-${var.project_name}-cloudwatch-metrics-lambda-policy"
  role = aws_iam_role.cloudwatch_metrics_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:ListFunctions"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Lambda Functions (Placeholder - will be implemented in subsequent tasks)
# ============================================================================

# Install Lambda dependencies locally
resource "null_resource" "install_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/lambda/requirements.txt")
  }

  provisioner "local-exec" {
    command     = <<-EOT
      rm -rf ${path.module}/lambda_build
      mkdir -p ${path.module}/lambda_build/python
      pip install -r ${path.module}/lambda/requirements.txt -t ${path.module}/lambda_build/python --upgrade
    EOT
    working_dir = path.module
  }
}

# Package Lambda dependencies as a layer
data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_build"
  output_path = "${path.module}/lambda_layer.zip"
  depends_on  = [null_resource.install_dependencies]
}

# Lambda layer for dependencies
resource "aws_lambda_layer_version" "dashboard_dependencies" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "${var.environment}-${var.project_name}-dashboard-deps"
  compatible_runtimes = ["python3.11"]
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256

  depends_on = [data.archive_file.lambda_layer]
}

# Package Lambda functions (without dependencies)
data "archive_file" "lambda_functions" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_package.zip"
  excludes    = ["requirements.txt", "__pycache__", "*.pyc"]
}

# Pipeline Status Lambda
resource "aws_lambda_function" "pipeline_status" {
  filename         = data.archive_file.lambda_functions.output_path
  function_name    = "${var.environment}-${var.project_name}-pipeline-status"
  role             = aws_iam_role.pipeline_status_lambda.arn
  handler          = "pipeline_status.lambda_handler"
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  layers           = [aws_lambda_layer_version.dashboard_dependencies.arn]

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.cold_path_dynamodb_table
      KINESIS_STREAM_NAME = var.kinesis_stream_name
      SQS_QUEUE_URL       = var.scrubber_queue_url
      ENVIRONMENT         = var.environment
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for pipeline status Lambda
resource "aws_cloudwatch_log_group" "pipeline_status_lambda" {
  count             = var.use_localstack ? 0 : 1
  name              = "/aws/lambda/${aws_lambda_function.pipeline_status.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# Realtime Metrics Lambda
resource "aws_lambda_function" "realtime_metrics" {
  filename         = data.archive_file.lambda_functions.output_path
  function_name    = "${var.environment}-${var.project_name}-realtime-metrics"
  role             = aws_iam_role.realtime_metrics_lambda.arn
  handler          = "realtime_metrics.lambda_handler"
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 512
  layers           = [aws_lambda_layer_version.dashboard_dependencies.arn]

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      ENVIRONMENT         = var.environment
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for realtime metrics Lambda
resource "aws_cloudwatch_log_group" "realtime_metrics_lambda" {
  count             = var.use_localstack ? 0 : 1
  name              = "/aws/lambda/${aws_lambda_function.realtime_metrics.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Metrics Lambda
resource "aws_lambda_function" "cloudwatch_metrics" {
  filename         = data.archive_file.lambda_functions.output_path
  function_name    = "${var.environment}-${var.project_name}-cloudwatch-metrics"
  role             = aws_iam_role.cloudwatch_metrics_lambda.arn
  handler          = "cloudwatch_metrics.lambda_handler"
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  layers           = [aws_lambda_layer_version.dashboard_dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for CloudWatch metrics Lambda
resource "aws_cloudwatch_log_group" "cloudwatch_metrics_lambda" {
  count             = var.use_localstack ? 0 : 1
  name              = "/aws/lambda/${aws_lambda_function.cloudwatch_metrics.function_name}"
  retention_in_days = 30

  tags = var.tags
}

# ============================================================================
# API Gateway Methods and Integrations
# ============================================================================

# GET /api/pipeline-status
resource "aws_api_gateway_method" "pipeline_status_get" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.pipeline_status.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "pipeline_status_get" {
  rest_api_id             = aws_api_gateway_rest_api.dashboard.id
  resource_id             = aws_api_gateway_resource.pipeline_status.id
  http_method             = aws_api_gateway_method.pipeline_status_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.pipeline_status.invoke_arn
}

# GET /api/metrics/realtime
resource "aws_api_gateway_method" "metrics_realtime_get" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.metrics_realtime.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.language"  = false
    "method.request.querystring.license"   = false
    "method.request.querystring.startDate" = false
    "method.request.querystring.endDate"   = false
  }
}

resource "aws_api_gateway_integration" "metrics_realtime_get" {
  rest_api_id             = aws_api_gateway_rest_api.dashboard.id
  resource_id             = aws_api_gateway_resource.metrics_realtime.id
  http_method             = aws_api_gateway_method.metrics_realtime_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.realtime_metrics.invoke_arn
}

# GET /api/metrics/trending
resource "aws_api_gateway_method" "metrics_trending_get" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.metrics_trending.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "metrics_trending_get" {
  rest_api_id             = aws_api_gateway_rest_api.dashboard.id
  resource_id             = aws_api_gateway_resource.metrics_trending.id
  http_method             = aws_api_gateway_method.metrics_trending_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.realtime_metrics.invoke_arn
}

# GET /api/metrics/cloudwatch
resource "aws_api_gateway_method" "metrics_cloudwatch_get" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.metrics_cloudwatch.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "metrics_cloudwatch_get" {
  rest_api_id             = aws_api_gateway_rest_api.dashboard.id
  resource_id             = aws_api_gateway_resource.metrics_cloudwatch.id
  http_method             = aws_api_gateway_method.metrics_cloudwatch_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.cloudwatch_metrics.invoke_arn
}

# ============================================================================
# CORS Configuration
# ============================================================================

# OPTIONS method for /api/pipeline-status (CORS preflight)
resource "aws_api_gateway_method" "pipeline_status_options" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.pipeline_status.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "pipeline_status_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.pipeline_status.id
  http_method = aws_api_gateway_method.pipeline_status_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "pipeline_status_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.pipeline_status.id
  http_method = aws_api_gateway_method.pipeline_status_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "pipeline_status_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.pipeline_status.id
  http_method = aws_api_gateway_method.pipeline_status_options.http_method
  status_code = aws_api_gateway_method_response.pipeline_status_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# OPTIONS method for /api/metrics/realtime (CORS preflight)
resource "aws_api_gateway_method" "metrics_realtime_options" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.metrics_realtime.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "metrics_realtime_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_realtime.id
  http_method = aws_api_gateway_method.metrics_realtime_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "metrics_realtime_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_realtime.id
  http_method = aws_api_gateway_method.metrics_realtime_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "metrics_realtime_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_realtime.id
  http_method = aws_api_gateway_method.metrics_realtime_options.http_method
  status_code = aws_api_gateway_method_response.metrics_realtime_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# OPTIONS method for /api/metrics/trending (CORS preflight)
resource "aws_api_gateway_method" "metrics_trending_options" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.metrics_trending.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "metrics_trending_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_trending.id
  http_method = aws_api_gateway_method.metrics_trending_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "metrics_trending_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_trending.id
  http_method = aws_api_gateway_method.metrics_trending_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "metrics_trending_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_trending.id
  http_method = aws_api_gateway_method.metrics_trending_options.http_method
  status_code = aws_api_gateway_method_response.metrics_trending_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# OPTIONS method for /api/metrics/cloudwatch (CORS preflight)
resource "aws_api_gateway_method" "metrics_cloudwatch_options" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_resource.metrics_cloudwatch.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "metrics_cloudwatch_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_cloudwatch.id
  http_method = aws_api_gateway_method.metrics_cloudwatch_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "metrics_cloudwatch_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_cloudwatch.id
  http_method = aws_api_gateway_method.metrics_cloudwatch_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "metrics_cloudwatch_options" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_resource.metrics_cloudwatch.id
  http_method = aws_api_gateway_method.metrics_cloudwatch_options.http_method
  status_code = aws_api_gateway_method_response.metrics_cloudwatch_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ============================================================================
# Lambda Permissions for API Gateway
# ============================================================================

resource "aws_lambda_permission" "pipeline_status_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dashboard.execution_arn}/*/*"
}

resource "aws_lambda_permission" "realtime_metrics_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.realtime_metrics.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dashboard.execution_arn}/*/*"
}

resource "aws_lambda_permission" "cloudwatch_metrics_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_metrics.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dashboard.execution_arn}/*/*"
}

# ============================================================================
# API Gateway Deployment and Stage
# ============================================================================

resource "aws_api_gateway_deployment" "dashboard" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api.id,
      aws_api_gateway_resource.pipeline_status.id,
      aws_api_gateway_resource.metrics.id,
      aws_api_gateway_resource.metrics_realtime.id,
      aws_api_gateway_resource.metrics_trending.id,
      aws_api_gateway_resource.metrics_cloudwatch.id,
      aws_api_gateway_method.pipeline_status_get.id,
      aws_api_gateway_method.metrics_realtime_get.id,
      aws_api_gateway_method.metrics_trending_get.id,
      aws_api_gateway_method.metrics_cloudwatch_get.id,
      aws_api_gateway_integration.pipeline_status_get.id,
      aws_api_gateway_integration.metrics_realtime_get.id,
      aws_api_gateway_integration.metrics_trending_get.id,
      aws_api_gateway_integration.metrics_cloudwatch_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dashboard" {
  deployment_id = aws_api_gateway_deployment.dashboard.id
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  stage_name    = var.environment

  tags = var.tags
}

# API Gateway Custom Domain Name
resource "aws_api_gateway_domain_name" "dashboard" {
  count           = var.api_domain_name != "" ? 1 : 0
  domain_name     = var.api_domain_name
  certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : aws_acm_certificate.dashboard[0].arn

  endpoint_configuration {
    types = ["EDGE"]
  }

  tags = var.tags

  # Ensure certificate is validated before creating domain
  depends_on = [aws_acm_certificate_validation.dashboard]
}

# API Gateway Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "dashboard" {
  count       = var.api_domain_name != "" ? 1 : 0
  api_id      = aws_api_gateway_rest_api.dashboard.id
  stage_name  = aws_api_gateway_stage.dashboard.stage_name
  domain_name = aws_api_gateway_domain_name.dashboard[0].domain_name
}

# API Gateway Account settings for CloudWatch Logs
resource "aws_api_gateway_account" "dashboard" {
  cloudwatch_role_arn = var.api_gateway_cloudwatch_role_arn
}

# API Gateway throttling settings
resource "aws_api_gateway_method_settings" "dashboard" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  stage_name  = aws_api_gateway_stage.dashboard.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
    logging_level          = "INFO"
    data_trace_enabled     = true
    metrics_enabled        = true
  }

  depends_on = [aws_api_gateway_account.dashboard]
}

# Outputs are defined in outputs.tf
