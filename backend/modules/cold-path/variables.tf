variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "github_token" {
  description = "The GitHub token"
  type        = string
  sensitive   = true
}

variable "data_lake_bucket_name" {
  description = "The name of the data lake S3 bucket"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "dashboard_appsync_api_url" {
  description = "The AppSync GraphQL API endpoint for publishing crawler events"
  type        = string
  default     = ""
}

variable "appsync_api_id" {
  description = "The AppSync GraphQL API ID for IAM policy resource ARNs"
  type        = string
  default     = ""
}

variable "sentry_dsn_backend" {
  description = "Sentry DSN for backend (Lambda functions)"
  type        = string
}
