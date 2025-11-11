# Sentry DSN Secrets

resource "aws_secretsmanager_secret" "sentry_dsn_frontend" {
  name        = "${var.environment}-${var.project_name}-sentry-dsn-frontend"
  description = "Sentry DSN for frontend (React dashboard)"

  tags = {
    Name        = "${var.environment}-${var.project_name}-sentry-dsn-frontend"
    Environment = var.environment
    Component   = "sentry"
  }
}

resource "aws_secretsmanager_secret_version" "sentry_dsn_frontend" {
  secret_id     = aws_secretsmanager_secret.sentry_dsn_frontend.id
  secret_string = var.sentry_dsn_frontend
}

resource "aws_secretsmanager_secret" "sentry_dsn_backend" {
  name        = "${var.environment}-${var.project_name}-sentry-dsn-backend"
  description = "Sentry DSN for backend (Lambda functions)"

  tags = {
    Name        = "${var.environment}-${var.project_name}-sentry-dsn-backend"
    Environment = var.environment
    Component   = "sentry"
  }
}

resource "aws_secretsmanager_secret_version" "sentry_dsn_backend" {
  secret_id     = aws_secretsmanager_secret.sentry_dsn_backend.id
  secret_string = var.sentry_dsn_backend
}
