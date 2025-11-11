# Monitoring Module - Variables
variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cold_path_lambda_name" {
  description = "Name of the Cold Path Lambda function"
  type        = string
}

variable "hot_path_lambda_names" {
  description = "Names of Hot Path Lambda functions"
  type        = list(string)
}

variable "scrubber_lambda_name" {
  description = "Name of the Scrubber Lambda function"
  type        = string
}

variable "kinesis_stream_name" {
  description = "Name of the Kinesis Data Stream"
  type        = string
}

variable "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  type        = string
}

variable "neptune_cluster_id" {
  description = "ID of the Neptune cluster"
  type        = string
}
