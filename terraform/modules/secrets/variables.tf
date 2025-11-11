# Secrets Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}
