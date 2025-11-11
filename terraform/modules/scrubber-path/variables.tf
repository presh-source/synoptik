# Scrubber Path Module - Variables
variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_token_arn" {
  description = "ARN of the GitHub token in Secrets Manager"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  type        = string
}
