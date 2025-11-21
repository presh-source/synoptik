# Variables for AppSync Module

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "cold_path_dynamodb_table" {
  description = "Name of the DynamoDB table for cold path bookmarks"
  type        = string
}



variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
