# API Gateway Module - Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "api_name" {
  description = "Name of the API (will be prefixed with environment and project)"
  type        = string
}

variable "api_description" {
  description = "Description of the API"
  type        = string
  default     = ""
}

variable "endpoint_type" {
  description = "API Gateway endpoint type (REGIONAL, EDGE, PRIVATE)"
  type        = string
  default     = "REGIONAL"
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

variable "api_resources" {
  description = "Map of API resources to create"
  type = map(object({
    path_part   = string
    parent_path = string # Empty string for root, or key of parent resource
  }))
  default = {}
}

variable "api_methods" {
  description = "Map of API methods to create"
  type = map(object({
    resource_path      = string
    http_method        = string
    authorization      = string
    request_parameters = map(bool)
  }))
  default = {}
}

variable "lambda_integrations" {
  description = "Map of Lambda integrations"
  type = map(object({
    resource_path        = string
    lambda_invoke_arn    = string
    lambda_function_name = string
  }))
  default = {}
}

variable "enable_cors" {
  description = "Enable CORS for all resources"
  type        = bool
  default     = true
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "cloudwatch_role_arn" {
  description = "ARN of IAM role for API Gateway to write to CloudWatch"
  type        = string
  default     = ""
}

variable "custom_domain_name" {
  description = "Custom domain name for the API"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for custom domain"
  type        = string
  default     = ""
}

variable "base_path" {
  description = "Base path mapping for custom domain"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
