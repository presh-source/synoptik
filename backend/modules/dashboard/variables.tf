variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "cold_path_dynamodb_table" {
  description = "The name of the DynamoDB table for the cold path"
  type        = string
}

variable "sentry_dsn_backend" {
  description = "The Sentry DSN for the backend"
  type        = string
  sensitive   = true
}

variable "app_version" {
  description = "The version of the application"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "Custom domain name for the frontend"
  type        = string
  default     = ""
}

variable "api_domain_name" {
  description = "Custom domain name for the REST API"
  type        = string
  default     = ""
}

variable "appsync_appsync_domain_name" {
  description = "Custom domain name for the GraphQL API (AppSync)"
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "The name of the Route 53 hosted zone (e.g. example.com)"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain (must be in us-east-1 region)"
  type        = string
  default     = ""
}

variable "api_gateway_cloudwatch_role_arn" {
  description = "ARN of the IAM role for API Gateway to write to CloudWatch Logs"
  type        = string
}
