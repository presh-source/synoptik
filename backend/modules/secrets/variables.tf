variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token for API access"
  type        = string
  sensitive   = true
}

variable "sentry_dsn_frontend" {
  description = "Sentry DSN for frontend (React dashboard)"
  type        = string
  sensitive   = true
}

variable "sentry_dsn_backend" {
  description = "Sentry DSN for backend (Lambda functions)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}