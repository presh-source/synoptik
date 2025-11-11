# Synoptik - Terraform Infrastructure

This directory contains the Terraform infrastructure code for the Synoptik platform.

## Project Structure

```
terraform/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Global variables
├── outputs.tf              # Global outputs
├── backend.tf              # Backend configuration documentation
├── environments/           # Environment-specific configurations
│   ├── dev/
│   │   ├── terraform.tfvars
│   │   └── backend.tfvars
│   ├── staging/
│   │   ├── terraform.tfvars
│   │   └── backend.tfvars
│   └── prod/
│       ├── terraform.tfvars
│       └── backend.tfvars
└── modules/                # Terraform modules
    ├── iam/                # IAM roles and policies
    ├── secrets/            # Secrets Manager (GitHub token)
    ├── data-lake/          # S3 Data Lake
    ├── cold-path/          # Cold Path pipeline
    ├── hot-path/           # Hot Path pipeline
    ├── scrubber-path/      # Scrubber Path pipeline
    ├── networking/         # VPC, subnets, security groups
    ├── data-stores/        # OpenSearch, Neptune, Athena
    ├── dashboard/          # API Gateway, Lambda, frontend
    └── monitoring/         # CloudWatch dashboards and alarms
```

## Prerequisites

1. **Terraform**: Install Terraform >= 1.5.0
   ```bash
   brew install terraform  # macOS
   ```

2. **AWS CLI**: Configure AWS credentials
   ```bash
   aws configure
   ```

3. **GitHub Personal Access Token**: Create a token with `public_repo` scope
   - Go to: https://github.com/settings/tokens
   - Generate new token (classic)
   - Select scope: `public_repo`
   - Copy the token

## Initial Setup

### 1. Create S3 Backend Resources

Before running Terraform, you need to manually create the S3 bucket and DynamoDB table for state management:

```bash
# Set your environment
ENV=dev  # or staging, prod

# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket synoptik-terraform-state-${ENV} \
  --region us-east-1

# Enable versioning on the bucket
aws s3api put-bucket-versioning \
  --bucket synoptik-terraform-state-${ENV} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket synoptik-terraform-state-${ENV} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name synoptik-terraform-locks-${ENV} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Set GitHub Token

Export your GitHub token as an environment variable:

```bash
export TF_VAR_github_token="your_github_token_here"
```

Alternatively, you can create a `terraform.tfvars` file (DO NOT commit this):

```hcl
github_token = "your_github_token_here"
```

## Deployment

### Development Environment

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform with dev backend
terraform init -backend-config=environments/dev/backend.tfvars

# Review the plan
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply the configuration
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Staging Environment

```bash
# Initialize Terraform with staging backend
terraform init -reconfigure -backend-config=environments/staging/backend.tfvars

# Review the plan
terraform plan -var-file=environments/staging/terraform.tfvars

# Apply the configuration
terraform apply -var-file=environments/staging/terraform.tfvars
```

### Production Environment

```bash
# Initialize Terraform with prod backend
terraform init -reconfigure -backend-config=environments/prod/backend.tfvars

# Review the plan
terraform plan -var-file=environments/prod/terraform.tfvars

# Apply the configuration (requires approval)
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Module Implementation Status

- ✅ **iam**: IAM roles and policies (Complete)
- ✅ **secrets**: GitHub token in Secrets Manager (Complete)
- ✅ **data-lake**: S3 Data Lake with lifecycle policies (Complete)
- ⏳ **cold-path**: To be implemented in Task 2
- ⏳ **hot-path**: To be implemented in Task 5
- ⏳ **scrubber-path**: To be implemented in Task 6
- ⏳ **networking**: To be implemented in Task 9.3
- ⏳ **data-stores**: To be implemented in Task 4
- ⏳ **dashboard**: To be implemented in Tasks 7-8
- ⏳ **monitoring**: To be implemented in Task 10

## Outputs

After successful deployment, Terraform will output:

- `data_lake_bucket_name`: S3 bucket for raw data storage
- `github_token_secret_arn`: ARN of the GitHub token secret
- `cold_path_dynamodb_table`: DynamoDB table for Cold Path state
- `opensearch_endpoint`: OpenSearch cluster endpoint
- `neptune_endpoint`: Neptune cluster endpoint
- `dashboard_api_url`: API Gateway URL
- `dashboard_frontend_url`: Frontend application URL

## State Management

Terraform state is stored in S3 with:
- **Encryption**: AES256
- **Versioning**: Enabled
- **Locking**: DynamoDB table prevents concurrent modifications

## Security Best Practices

1. **Never commit secrets**: Use environment variables or AWS Secrets Manager
2. **Use least privilege IAM**: Each module has minimal required permissions
3. **Enable encryption**: All data stores use encryption at rest
4. **Private subnets**: OpenSearch and Neptune deployed in private subnets
5. **State locking**: DynamoDB prevents concurrent state modifications

## Troubleshooting

### Backend Initialization Errors

If you see "Error configuring the backend":
- Ensure S3 bucket and DynamoDB table exist
- Verify AWS credentials have access to these resources
- Check bucket name matches backend.tfvars

### Module Dependency Errors

If you see "Module not yet implemented":
- Some modules are placeholders for future tasks
- They provide empty outputs to satisfy dependencies
- Implementation will be added in subsequent tasks

### GitHub Token Errors

If you see "github_token variable not set":
- Export: `export TF_VAR_github_token="your_token"`
- Or add to terraform.tfvars (don't commit)

## Cleanup

To destroy all resources:

```bash
# WARNING: This will delete all infrastructure
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Next Steps

1. Implement Cold Path module (Task 2)
2. Implement data transformation and bulk loading (Task 3)
3. Set up query engine infrastructure (Task 4)
4. Implement Hot Path pipeline (Task 5)
5. Implement Scrubber Path pipeline (Task 6)
