# ============================================================================
# IAM Role for Lambda
# ============================================================================

resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-${var.project_name}-${var.function_name}-exec"

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

# ============================================================================
# IAM Policy for Lambda
# ============================================================================

# Default policy for logging
resource "aws_iam_role_policy" "logging" {
  name = "${var.environment}-${var.project_name}-${var.function_name}-logging-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

# Optional custom policy
resource "aws_iam_role_policy" "custom" {
  count = var.iam_policy_document != "" ? 1 : 0

  name   = "${var.environment}-${var.project_name}-${var.function_name}-custom-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = var.iam_policy_document
}

# Optional managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  count = length(var.managed_policy_arns) > 0 ? length(var.managed_policy_arns) : 0

  role       = aws_iam_role.lambda_exec.name
  policy_arn = var.managed_policy_arns[count.index]
}


# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.environment}-${var.project_name}-${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ============================================================================
# Lambda Function
# ============================================================================

resource "aws_lambda_function" "this" {
  function_name = "${var.environment}-${var.project_name}-${var.function_name}"
  description   = var.function_description
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  role          = aws_iam_role.lambda_exec.arn
  filename      = var.filename
  source_code_hash = var.source_code_hash

  layers = var.layers

  environment {
    variables = var.environment_variables
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.logging,
  ]
}
