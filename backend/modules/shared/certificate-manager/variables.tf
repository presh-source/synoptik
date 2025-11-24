# Domain and Certificate Module - Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "certificate_name" {
  description = "Name identifier for the certificate (e.g., 'frontend', 'api')"
  type        = string
  default     = "main"
}

variable "domain_name" {
  description = "Domain name for the certificate and DNS records"
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Name of the Route53 hosted zone (if different from custom_domain_name)"
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional domain names to include in the certificate"
  type        = list(string)
  default     = []
}

variable "validation_method" {
  description = "Certificate validation method (DNS or EMAIL)"
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "Validation method must be either DNS or EMAIL."
  }
}

variable "create_certificate" {
  description = "Whether to create an ACM certificate"
  type        = bool
  default     = true
}

variable "create_dns_records" {
  description = "Whether to create Route53 DNS records"
  type        = bool
  default     = true
}

variable "target_domain_name" {
  description = "Target domain name for DNS alias record (e.g., CloudFront or API Gateway domain)"
  type        = string
}

variable "target_zone_id" {
  description = "Target zone ID for DNS alias record (e.g., CloudFront or API Gateway zone ID)"
  type        = string
}

variable "evaluate_target_health" {
  description = "Whether to evaluate target health for alias records"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Whether to create AAAA (IPv6) DNS records"
  type        = bool
  default     = true
}

variable "use_cname" {
  description = "Use CNAME record instead of alias (not recommended for root domains)"
  type        = bool
  default     = false
}

variable "cname_ttl" {
  description = "TTL for CNAME records"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
