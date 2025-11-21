# Variables

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod, local)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "local"], var.environment)
    error_message = "Environment must be dev, staging, prod, or local."
  }
}

variable "github_token" {
  description = "GitHub Personal Access Token for API access"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "synoptik"
}

variable "sentry_dsn_frontend" {
  description = "Sentry DSN for frontend (React dashboard)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sentry_dsn_backend" {
  description = "Sentry DSN for backend (Lambda functions)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_version" {
  description = "Application version for release tracking"
  type        = string
  default     = "1.0.0"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "synoptik"
  }
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
  description = "ARN of existing ACM certificate for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "enable_appsync" {
  description = "Enable AppSync GraphQL API module"
  type        = bool
  default     = true
}
