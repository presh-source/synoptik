variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "use_localstack" {
  description = "Whether to use LocalStack for AWS services"
  type        = bool
  default     = false
}
