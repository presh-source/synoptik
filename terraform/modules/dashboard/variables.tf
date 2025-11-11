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