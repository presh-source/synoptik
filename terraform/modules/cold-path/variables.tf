variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "github_token_arn" {
  description = "The ARN of the GitHub token secret in Secrets Manager"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "The name of the S3 bucket for the data lake"
  type        = string
}

variable "lambda_timeout" {
  description = "The timeout for the Lambda function in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory" {
  description = "The memory size for the Lambda function in MB"
  type        = number
  default     = 512
}

variable "requests_per_execution" {
  description = "The number of GitHub API requests to make per Lambda execution"
  type        = number
  default     = 10
}

variable "sleep_interval" {
  description = "The sleep interval between GitHub API requests in seconds"
  type        = number
  default     = 1
}