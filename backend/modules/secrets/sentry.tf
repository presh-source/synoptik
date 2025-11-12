# Sentry DSN Secrets

resource "aws_secretsmanager_secret" "sentry_dsn_frontend" {
  name                    = "${var.environment}-${var.project_name}-sentry-q"
  description             = "Sentry DSN for frontend (React dashboard)"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "sentry_dsn_frontend" {
  secret_id     = aws_secretsmanager_secret.sentry_dsn_frontend.id
  secret_string = var.sentry_dsn_frontend
}

resource "aws_secretsmanager_secret" "sentry_dsn_backend" {
  name                    = "${var.environment}-${var.project_name}-sentry-backend-dsn"
  description             = "Sentry DSN for backend (Lambda functions)"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "sentry_dsn_backend" {
  secret_id     = aws_secretsmanager_secret.sentry_dsn_backend.id
  secret_string = var.sentry_dsn_backend
}
