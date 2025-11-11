# Cold Path Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_token_arn" {
  description = "ARN of the GitHub token secret in Secrets Manager"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  type        = string
}

variable "requests_per_execution" {
  description = "Number of API requests per Lambda execution"
  type        = number
  default     = 1050
}

variable "sleep_interval" {
  description = "Sleep interval between API requests in seconds"
  type        = number
  default     = 0.8
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900 # 15 minutes
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}
