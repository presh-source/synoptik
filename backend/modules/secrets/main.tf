# Secrets Manager Module - GitHub Token Storage

resource "aws_secretsmanager_secret" "github_token" {
  name                    = "${var.environment}-${var.project_name}-github-token"
  description             = "GitHub Personal Access Token for ${var.project_name} API access"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token

}

# Rotation configuration (optional - requires Lambda function)
# Uncomment when rotation Lambda is implemented
# resource "aws_secretsmanager_secret_rotation" "github_token" {
#   secret_id           = aws_secretsmanager_secret.github_token.id
#   rotation_lambda_arn = aws_lambda_function.rotate_github_token.arn
#   
#   rotation_rules {
#     automatically_after_days = 90
#   }
# }
