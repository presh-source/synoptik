# Domain and Certificate Module

This module manages AWS ACM certificates and Route53 DNS records for custom domains. It handles certificate creation, DNS validation, and DNS record management for CloudFront, API Gateway, or other AWS services.

## Features

- **ACM Certificate Creation**: Creates SSL/TLS certificates in us-east-1 (required for CloudFront)
- **DNS Validation**: Automatic DNS validation record creation
- **Route53 Integration**: Creates A, AAAA, and CNAME records
- **Subject Alternative Names**: Support for multiple domains in one certificate
- **Flexible DNS**: Supports alias records (recommended) or CNAME records
- **IPv6 Support**: Optional AAAA record creation
- **Hosted Zone Lookup**: Automatic Route53 hosted zone discovery

## Usage

### Basic Example (CloudFront)

```hcl
module "frontend_domain" {
  source = "./modules/domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = "myproject"
  certificate_name = "frontend"
  domain_name      = "app.example.com"

  # CloudFront distribution details
  target_domain_name = aws_cloudfront_distribution.app.domain_name
  target_zone_id     = aws_cloudfront_distribution.app.hosted_zone_id

  tags = {
    Environment = "prod"
  }
}
```

### With Subject Alternative Names

```hcl
module "multi_domain_cert" {
  source = "./modules/domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = "myproject"
  certificate_name = "multi"
  domain_name      = "example.com"
  
  subject_alternative_names = [
    "www.example.com",
    "api.example.com"
  ]

  target_domain_name = aws_cloudfront_distribution.app.domain_name
  target_zone_id     = aws_cloudfront_distribution.app.hosted_zone_id

  tags = {
    Environment = "prod"
  }
}
```

### API Gateway Domain

```hcl
module "api_domain" {
  source = "./modules/domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name     = "myproject"
  certificate_name = "api"
  domain_name      = "api.example.com"

  # API Gateway custom domain details
  target_domain_name = aws_api_gateway_domain_name.api.cloudfront_domain_name
  target_zone_id     = aws_api_gateway_domain_name.api.cloudfront_zone_id

  tags = {
    Environment = "prod"
  }
}
```

### Certificate Only (No DNS)

```hcl
module "cert_only" {
  source = "./modules/domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name       = "myproject"
  certificate_name   = "cert"
  domain_name        = "example.com"
  create_dns_records = false

  tags = {
    Environment = "prod"
  }
}
```

### Using Existing Certificate

```hcl
module "dns_only" {
  source = "./modules/domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name       = "myproject"
  certificate_name   = "dns"
  domain_name        = "example.com"
  create_certificate = false

  target_domain_name = aws_cloudfront_distribution.app.domain_name
  target_zone_id     = aws_cloudfront_distribution.app.hosted_zone_id

  tags = {
    Environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project | string | - | yes |
| certificate_name | Name identifier for the certificate | string | "main" | no |
| domain_name | Domain name for certificate and DNS | string | "" | no |
| hosted_zone_name | Route53 hosted zone name | string | "" | no |
| subject_alternative_names | Additional domain names | list(string) | [] | no |
| validation_method | Certificate validation method | string | "DNS" | no |
| create_certificate | Whether to create ACM certificate | bool | true | no |
| create_dns_records | Whether to create Route53 DNS records | bool | true | no |
| target_domain_name | Target domain for DNS alias | string | "" | no |
| target_zone_id | Target zone ID for DNS alias | string | "" | no |
| evaluate_target_health | Evaluate target health for alias | bool | false | no |
| enable_ipv6 | Create AAAA (IPv6) records | bool | true | no |
| use_cname | Use CNAME instead of alias | bool | false | no |
| cname_ttl | TTL for CNAME records | number | 300 | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| certificate_arn | ARN of the ACM certificate |
| certificate_domain_name | Domain name of the certificate |
| certificate_status | Status of the certificate |
| hosted_zone_id | ID of the Route53 hosted zone |
| hosted_zone_name | Name of the Route53 hosted zone |
| dns_record_name | Name of the created DNS record |
| dns_record_fqdn | FQDN of the created DNS record |
| validation_record_fqdns | FQDNs of validation records |

## Provider Configuration

This module requires a provider alias for us-east-1 region (CloudFront requirement):

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "domain" {
  source = "./modules/domain-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  # ... configuration
}
```

## DNS Record Types

### Alias Records (Recommended)
- Used for AWS services (CloudFront, API Gateway, ALB, etc.)
- No additional charge
- Supports root domains
- Automatic health checks (optional)
- Created when `use_cname = false`

### CNAME Records
- Used for non-AWS targets
- Cannot be used for root domains
- Has TTL configuration
- Created when `use_cname = true`

## Certificate Validation

The module supports two validation methods:

### DNS Validation (Recommended)
- Automatic validation record creation
- No manual intervention required
- Validation completes in minutes
- Set `validation_method = "DNS"`

### Email Validation
- Requires manual email confirmation
- Slower validation process
- Set `validation_method = "EMAIL"`

## Hosted Zone Discovery

The module automatically discovers the Route53 hosted zone:
- If `hosted_zone_name` is provided, uses that zone
- Otherwise, extracts root domain from `domain_name`
- Example: `app.example.com` → looks for `example.com` zone

## Best Practices

1. **Use DNS Validation**: Faster and automated
2. **Use Alias Records**: Better performance and no additional cost
3. **Enable IPv6**: Modern standard, no downside
4. **Certificate in us-east-1**: Required for CloudFront
5. **Subject Alternative Names**: Include www and non-www variants
6. **Separate Certificates**: Use different certificates for different services

## Common Patterns

### Frontend + API Domains

```hcl
# Frontend certificate and DNS
module "frontend_domain" {
  source = "./modules/domain-certificate"
  # ... configuration for app.example.com
}

# API certificate and DNS
module "api_domain" {
  source = "./modules/domain-certificate"
  # ... configuration for api.example.com
}
```

### Root and WWW Domains

```hcl
module "root_domain" {
  source = "./modules/domain-certificate"

  domain_name = "example.com"
  subject_alternative_names = ["www.example.com"]
  # ... other configuration
}
```

## Troubleshooting

### Certificate Validation Timeout
- Check that Route53 hosted zone exists
- Verify DNS propagation: `dig +short TXT _validation.example.com`
- Increase timeout in certificate validation resource

### DNS Record Creation Fails
- Verify hosted zone exists and is accessible
- Check IAM permissions for Route53
- Ensure domain matches hosted zone

### Certificate Not in us-east-1
- Verify provider alias is configured correctly
- Check that `providers` block is passed to module

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- Route53 hosted zone must exist
- IAM permissions for ACM and Route53

## Notes

- Certificates are created in us-east-1 for CloudFront compatibility
- DNS validation records are automatically cleaned up on destroy
- Certificate validation can take 5-10 minutes
- Alias records are preferred over CNAME for AWS services
