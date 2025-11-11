# Dashboard Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch cluster"
  type        = string
}

variable "neptune_endpoint" {
  description = "Endpoint of the Neptune cluster"
  type        = string
}

variable "cold_path_dynamodb_table" {
  description = "Name of the Cold Path DynamoDB table"
  type        = string
}

variable "kinesis_stream_name" {
  description = "Name of the Kinesis Data Stream"
  type        = string
}

variable "scrubber_queue_url" {
  description = "URL of the Scrubber SQS queue"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "synoptik"
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (optional)"
  type        = string
  default     = ""
}

variable "custom_domain_name" {
  description = "Custom domain name for the dashboard (optional)"
  type        = string
  default     = ""
}
