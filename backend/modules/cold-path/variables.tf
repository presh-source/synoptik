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

variable "aws_sdk_pandas_layer_version" {
  description = "Version of AWS SDK Pandas layer for us-east-1. Check https://aws-sdk-pandas.readthedocs.io/en/stable/layers.html for latest"
  type        = number
  default     = 23 # Known working version for Python 3.11
}

variable "aws_powertools_layer_version" {
  description = "Version of AWS Lambda Powertools layer for Python 3.11. Check https://awslabs.github.io/aws-lambda-powertools-python/latest/core/layers/ for latest"
  type        = number
  default     = 28 # Known working version for Python 3.11

}