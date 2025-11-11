# Project Naming - Synoptik

## Project Name

**Official Name**: Synoptik

## Resource Naming Convention

All AWS resources and infrastructure components use the "synoptik" naming prefix:

### Infrastructure Resources

- **S3 Buckets**: `synoptik-*`
  - Data Lake: `synoptik-data-lake-{env}`
  - Dashboard: `synoptik-dashboard-{env}`
  - LocalStack: `synoptik-dashboard-local`

- **DynamoDB Tables**: `synoptik-*`
  - Cold Path State: `synoptik-cold-path-state-{env}`
  - Terraform Locks: `synoptik-terraform-locks-{env}`

- **Lambda Functions**: `synoptik-*`
  - Cold Path Ingester: `synoptik-cold-path-ingester-{env}`
  - Hot Path Processor: `synoptik-hot-path-processor-{env}`
  - Scrubber Pinger: `synoptik-scrubber-pinger-{env}`

- **API Gateway**: `synoptik-dashboard-api-{env}`

- **CloudFront**: `synoptik-dashboard-{env}`

- **Kinesis Streams**: `synoptik-hot-path-stream-{env}`

- **SQS Queues**: `synoptik-scrubber-queue-{env}`

- **Secrets Manager**: `synoptik-github-token-{env}`

### LocalStack Resources

- **Container Name**: `synoptik-localstack`
- **S3 Bucket**: `synoptik-dashboard-local`
- **Environment**: `local`

### Application Names

- **Dashboard Package**: `synoptik-dashboard`
- **Dashboard Title**: "Synoptik Dashboard"
- **Sidebar Title**: "Synoptik"
- **Browser Title**: "Synoptik Dashboard"

### Terraform Variables

```hcl
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "synoptik"
}
```

### Environment Suffixes

- **Development**: `dev`
- **Staging**: `staging`
- **Production**: `prod`
- **Local**: `local`

### Example Resource Names

```
# Development Environment
synoptik-data-lake-dev
synoptik-dashboard-api-dev
synoptik-cold-path-ingester-dev

# Production Environment
synoptik-data-lake-prod
synoptik-dashboard-api-prod
synoptik-cold-path-ingester-prod

# LocalStack
synoptik-dashboard-local
synoptik-localstack (container)
```

### URLs

**LocalStack Dashboard**:
- Direct: `http://localhost:4566/synoptik-dashboard-local/index.html`
- S3 Website: `http://synoptik-dashboard-local.s3-website.localhost.localstack.cloud:4566`

**AWS Dashboard** (after deployment):
- CloudFront: `https://{distribution-id}.cloudfront.net`
- Custom Domain: `https://dashboard.yourdomain.com` (if configured)

### Git Repository

The repository directory is named `Synoptik` (capital S).

### Code References

All code, documentation, and configuration files use "synoptik" (lowercase) or "Synoptik" (capitalized for titles).

## Historical Note

The project was initially referred to as "GitHub Digital Twin" in some design documents and specifications. All user-facing components, infrastructure resources, and deployment configurations now use "Synoptik" as the official project name.

Design documents in `.kiro/specs/github-digital-twin/` retain the original naming for historical reference and traceability to requirements.
