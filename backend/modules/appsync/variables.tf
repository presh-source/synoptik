variable "appsync_appsync_domain_name" {
  description = "The custom domain name for the GraphQL API"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for the GraphQL API custom domain"
  type        = string
  default     = ""
}
