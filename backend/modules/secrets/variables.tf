variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token for API access"
  type        = string
  sensitive   = true
}

variable "sentry_dsn_frontend" {
  description = "Sentry DSN for frontend"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sentry_dsn_backend" {
  description = "Sentry DSN for backend"
  type        = string
  sensitive   = true
  default     = ""
}
