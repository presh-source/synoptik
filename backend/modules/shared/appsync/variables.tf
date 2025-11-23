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
  default     = {}
}

variable "schema" {
  description = "GraphQL schema"
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

variable "hosted_zone_name" {
  description = "The name of the Route53 hosted zone"
  type        = string
  default     = ""
}

variable "datasources" {
  description = "Map of AppSync datasources"
  type = map(object({
    type             = string
    description      = optional(string)
    service_role_arn = optional(string)
    lambda_config = optional(object({
      function_arn = string
    }))
    dynamodb_config = optional(object({
      table_name = string
      region     = optional(string)
    }))
    http_config = optional(object({
      endpoint = string
    }))
    none_config = optional(bool) # for NONE type
  }))
  default = {}
}

variable "resolvers" {
  description = "Map of AppSync resolvers"
  type = map(object({
    type              = string # Query, Mutation, Subscription
    field             = string
    datasource        = string
    request_template  = string
    response_template = string
    caching_config = optional(object({
      ttl = number
    }))
  }))
  default = {}
}

variable "functions" {
  description = "Map of AppSync functions"
  type = map(object({
    name              = string
    datasource        = string
    request_template  = string
    response_template = string
  }))
  default = {}
}
