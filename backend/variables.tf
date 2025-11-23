# Variables
locals {
  merged_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

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

variable "frontend_domain_name" {
  description = "Custom domain name for the frontend"
  type        = string
  default     = ""
}

variable "api_gateway_domain_name" {
  description = "Custom domain name for the API"
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
