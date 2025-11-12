# Synoptik - Variables

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

variable "localstack_config" {
  description = "LocalStack configuration for local development"
  type        = map(string)
  default = {
    enabled  = "false"
    endpoint = "http://localhost:4566"
  }
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
    ManagedBy = "Terraform"
  }
}
