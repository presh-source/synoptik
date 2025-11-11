# GitHub Digital Twin - Variables

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
  description = "Project name for resource naming"
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
