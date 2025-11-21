variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the AppSync API"
  type        = map(string)
}

variable "cold_path_dynamodb_table" {
  description = "The name of the DynamoDB table for cold path state"
  type        = string
}

variable "appsync_domain_name" {
  description = "The custom domain name for the GraphQL API"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for the GraphQL API custom domain"
  type        = string
  default     = ""
}
