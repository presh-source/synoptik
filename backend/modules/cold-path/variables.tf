variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "github_token_arn" {
  description = "The ARN of the GitHub token secret"
  type        = string
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

variable "lambda_timeout" {
  description = "The timeout for the Lambda function"
  type        = number
  default     = 300
}

variable "lambda_memory" {
  description = "The memory size for the Lambda function"
  type        = number
  default     = 512
}

variable "requests_per_execution" {
  description = "The number of requests per execution"
  type        = number
  default     = 10
}

variable "sleep_interval" {
  description = "The sleep interval between requests"
  type        = number
  default     = 1
}
