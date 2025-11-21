# AWS Secrets Manager for AppSync API Key
# This stores the API key securely for use by frontend and other services

resource "aws_secretsmanager_secret" "appsync_api_key" {
  name        = "${var.environment}-${var.project_name}-appsync-api-key"
  description = "AppSync GraphQL API key for frontend authentication"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "appsync_api_key" {
  secret_id     = aws_secretsmanager_secret.appsync_api_key.id
  secret_string = jsonencode({
    api_key              = aws_appsync_api_key.main.key
    graphql_endpoint     = aws_appsync_graphql_api.main.uris["GRAPHQL"]
    realtime_endpoint    = aws_appsync_graphql_api.main.uris["REALTIME"]
  })
}
