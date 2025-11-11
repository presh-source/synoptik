# Synoptik - Terraform Project Structure

## Overview

This document describes the Terraform project structure for the Synoptik platform. The infrastructure is organized into modular components that can be deployed independently or together.

## Directory Structure

```
terraform/
├── main.tf                          # Root module - orchestrates all components
├── variables.tf                     # Global input variables
├── outputs.tf                       # Global outputs
├── backend.tf                       # Backend configuration documentation
├── Makefile                         # Common operations helper
├── README.md                        # Setup and deployment guide
├── .gitignore                       # Git ignore patterns
│
├── environments/                    # Environment-specific configurations
│   ├── dev/
│   │   ├── terraform.tfvars        # Dev variable values
│   │   └── backend.tfvars          # Dev backend configuration
│   ├── staging/
│   │   ├── terraform.tfvars        # Staging variable values
│   │   └── backend.tfvars          # Staging backend configuration
│   └── prod/
│       ├── terraform.tfvars        # Prod variable values
│       └── backend.tfvars          # Prod backend configuration
│
├── scripts/
│   └── setup-backend.sh            # Automated backend setup script
│
└── modules/                         # Reusable Terraform modules
    │
    ├── iam/                         # ✅ COMPLETE
    │   ├── main.tf                 # IAM roles for Lambda, Glue, EventBridge, Firehose
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── secrets/                     # ✅ COMPLETE
    │   ├── main.tf                 # AWS Secrets Manager for GitHub token
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── data-lake/                   # ✅ COMPLETE
    │   ├── main.tf                 # S3 bucket with encryption, lifecycle, partitioning
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── cold-path/                   # ⏳ TASK 2
    │   ├── main.tf                 # EventBridge, CrawlerLambda, DynamoDB
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── hot-path/                    # ⏳ TASK 5
    │   ├── main.tf                 # Kinesis, EventsPoller, GraphUpdater, Firehose
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── scrubber-path/               # ⏳ TASK 6
    │   ├── main.tf                 # SQS, Feeder Glue Job, PingerLambda
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── networking/                  # ⏳ TASK 9.3
    │   ├── main.tf                 # VPC, subnets, security groups, VPC endpoints
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── data-stores/                 # ⏳ TASK 4
    │   ├── main.tf                 # OpenSearch, Neptune, Athena/Glue Catalog
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── dashboard/                   # ⏳ TASKS 7-8
    │   ├── main.tf                 # API Gateway, Lambda functions, S3/CloudFront
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── monitoring/                  # ⏳ TASK 10
        ├── main.tf                 # CloudWatch dashboards, alarms, SNS topics
        ├── variables.tf
        └── outputs.tf
```

## Module Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                         Root Module                         │
│                         (main.tf)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌──────────┐         ┌──────────┐
   │   IAM   │          │ Secrets  │         │Data Lake │
   │  Roles  │          │ Manager  │         │   (S3)   │
   └─────────┘          └──────────┘         └──────────┘
        │                     │                     │
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌──────────┐         ┌──────────┐         ┌──────────┐
   │   Cold   │         │   Hot    │         │ Scrubber │
   │   Path   │         │   Path   │         │   Path   │
   └──────────┘         └──────────┘         └──────────┘
        │                     │                     │
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌──────────┐         ┌──────────┐         ┌──────────┐
   │   Data   │         │Dashboard │         │Monitoring│
   │  Stores  │         │          │         │          │
   └──────────┘         └──────────┘         └──────────┘
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Deployed System │
                    └──────────────────┘
```

## Module Descriptions

### Core Infrastructure

#### IAM Module (✅ Complete)
- **Purpose**: Centralized IAM role management
- **Resources**:
  - Lambda execution role with CloudWatch Logs permissions
  - Glue execution role for ETL jobs
  - EventBridge role for Lambda invocation
  - Firehose role for OpenSearch delivery
- **Dependencies**: None

#### Secrets Module (✅ Complete)
- **Purpose**: Secure storage of GitHub API token
- **Resources**:
  - AWS Secrets Manager secret
  - Secret version with token value
  - Optional rotation configuration (90 days)
- **Dependencies**: None

#### Data Lake Module (✅ Complete)
- **Purpose**: Raw data storage with lifecycle management
- **Resources**:
  - S3 bucket with encryption (AES256)
  - Lifecycle policies (Glacier after 90 days)
  - Public access blocking
  - Partitioning structure for cold-path and hot-path
- **Dependencies**: None

### Pipeline Modules

#### Cold Path Module (⏳ Task 2)
- **Purpose**: Historical repository crawl pipeline
- **Resources**:
  - EventBridge cron rule (15 minutes)
  - CrawlerLambda function
  - DynamoDB CrawlState table
  - IAM policies for S3, DynamoDB, Secrets Manager
- **Dependencies**: IAM, Secrets, Data Lake

#### Hot Path Module (⏳ Task 5)
- **Purpose**: Real-time event streaming pipeline
- **Resources**:
  - Kinesis Data Stream (10 shards)
  - EventsPoller Lambda
  - GraphUpdater Lambda
  - Kinesis Data Firehose to OpenSearch
  - Transformation Lambda for Firehose
- **Dependencies**: IAM, Secrets, Data Stores

#### Scrubber Path Module (⏳ Task 6)
- **Purpose**: Deletion detection and cleanup
- **Resources**:
  - SQS queue with DLQ
  - Feeder Glue Job (weekly)
  - PingerLambda function
  - IAM policies for SQS, Glue, OpenSearch, Neptune
- **Dependencies**: IAM, Secrets, Data Lake, Data Stores

### Data and Application Modules

#### Networking Module (⏳ Task 9.3)
- **Purpose**: VPC and network security
- **Resources**:
  - VPC with public and private subnets
  - Security groups for OpenSearch and Neptune
  - VPC endpoints for S3, DynamoDB, Kinesis
  - NAT Gateway for private subnet internet access
- **Dependencies**: None

#### Data Stores Module (⏳ Task 4)
- **Purpose**: Query engines for different access patterns
- **Resources**:
  - Amazon OpenSearch cluster (3 data nodes, 3 masters)
  - Amazon Neptune cluster (3 instances, 2 read replicas)
  - AWS Glue Data Catalog for Athena
  - Athena workgroup
- **Dependencies**: Networking, Data Lake

#### Dashboard Module (⏳ Tasks 7-8)
- **Purpose**: Observability and metrics dashboard
- **Resources**:
  - API Gateway REST API
  - Lambda functions for backend APIs
  - S3 bucket for React frontend
  - CloudFront distribution
  - Cognito user pool (optional)
- **Dependencies**: Data Stores, Cold Path, Hot Path, Scrubber Path

#### Monitoring Module (⏳ Task 10)
- **Purpose**: System health monitoring and alerting
- **Resources**:
  - CloudWatch dashboards (Cold/Hot/Scrubber paths)
  - CloudWatch alarms (error rates, stalled pipelines)
  - SNS topics for notifications
  - CloudWatch Logs groups
- **Dependencies**: All pipeline modules

## State Management

### Backend Configuration

Each environment has its own S3 backend:

- **Dev**: `synoptik-terraform-state-dev`
- **Staging**: `synoptik-terraform-state-staging`
- **Prod**: `synoptik-terraform-state-prod`

State locking uses DynamoDB tables:

- **Dev**: `synoptik-terraform-locks-dev`
- **Staging**: `synoptik-terraform-locks-staging`
- **Prod**: `synoptik-terraform-locks-prod`

### State File Structure

```
s3://synoptik-terraform-state-{env}/
└── {env}/
    └── terraform.tfstate
```

## Variable Management

### Global Variables (variables.tf)
- `aws_region`: AWS region (default: us-east-1)
- `environment`: Environment name (dev/staging/prod)
- `github_token`: GitHub API token (sensitive)
- `vpc_cidr`: VPC CIDR block
- `project_name`: Project name for resource naming

### Environment-Specific Variables
Each environment can override defaults in `environments/{env}/terraform.tfvars`

### Sensitive Variables
- GitHub token: Set via `TF_VAR_github_token` environment variable
- Never commit sensitive values to version control

## Deployment Workflow

1. **Setup Backend** (one-time per environment)
   ```bash
   make setup-backend-dev
   ```

2. **Initialize Terraform**
   ```bash
   make init-dev
   ```

3. **Plan Changes**
   ```bash
   make plan-dev
   ```

4. **Apply Changes**
   ```bash
   make apply-dev
   ```

## Implementation Roadmap

| Task | Module | Status | Dependencies |
|------|--------|--------|--------------|
| 1 | iam, secrets, data-lake | ✅ Complete | None |
| 2 | cold-path | ⏳ Pending | Task 1 |
| 3 | Glue transformation | ⏳ Pending | Task 2 |
| 4 | data-stores | ⏳ Pending | networking |
| 5 | hot-path | ⏳ Pending | Task 4 |
| 6 | scrubber-path | ⏳ Pending | Task 4 |
| 7-8 | dashboard | ⏳ Pending | Tasks 2,5,6 |
| 9.3 | networking | ⏳ Pending | None |
| 10 | monitoring | ⏳ Pending | All pipelines |

## Best Practices

1. **Module Isolation**: Each module is self-contained with its own variables and outputs
2. **Explicit Dependencies**: Use `depends_on` to enforce deployment order
3. **Tagging Strategy**: All resources tagged with Environment and Project
4. **State Locking**: DynamoDB prevents concurrent modifications
5. **Encryption**: All data stores use encryption at rest
6. **Least Privilege**: IAM roles have minimal required permissions
7. **Version Pinning**: Terraform and provider versions are pinned
8. **Environment Separation**: Complete isolation between dev/staging/prod

## Troubleshooting

See [README.md](README.md#troubleshooting) for common issues and solutions.
