variable "use_localstack" {
  description = "Whether to use LocalStack for AWS services"
  type        = bool
  default     = false
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "opensearch_endpoint" {
  description = "The endpoint of the OpenSearch cluster"
  type        = string
}

variable "neptune_endpoint" {
  description = "The endpoint of the Neptune cluster"
  type        = string
}

variable "cold_path_dynamodb_table" {
  description = "The name of the DynamoDB table for the cold path"
  type        = string
}

variable "kinesis_stream_name" {
  description = "The name of the Kinesis stream for the hot path"
  type        = string
}

variable "scrubber_queue_url" {
  description = "The URL of the SQS queue for the scrubber path"
  type        = string
}
variable "sentry_dsn_secret_arn" {
  description = "ARN of the Sentry DSN secret in Secrets Manager"
  type        = string
  default     = ""
}

variable "app_version" {
  description = "Application version for release tracking"
  type        = string
  default     = "1.0.0"
}

variable "sentry_traces_sample_rate" {
  description = "Sentry traces sample rate (0.0 to 1.0)"
  type        = string
  default     = "0.1"
}
