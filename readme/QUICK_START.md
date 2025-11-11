# Quick Start Guide

Get the GitHub Digital Twin infrastructure up and running in minutes.

## Prerequisites Checklist

- [ ] Terraform >= 1.5.0 installed
- [ ] AWS CLI configured with credentials
- [ ] GitHub Personal Access Token created
- [ ] AWS account with appropriate permissions

## 5-Minute Setup (Development)

### Step 1: Clone and Navigate
```bash
cd terraform
```

### Step 2: Set GitHub Token
```bash
export TF_VAR_github_token="ghp_your_token_here"
```

### Step 3: Setup Backend
```bash
make setup-backend-dev
```

This creates:
- S3 bucket: `synoptik-terraform-state-dev`
- DynamoDB table: `synoptik-terraform-locks-dev`

### Step 4: Initialize Terraform
```bash
make init-dev
```

### Step 5: Deploy Infrastructure
```bash
# Review what will be created
make plan-dev

# Deploy (requires confirmation)
make apply-dev
```

## What Gets Deployed (Task 1)

Currently implemented:
- ✅ IAM roles for Lambda, Glue, EventBridge, Firehose
- ✅ GitHub token stored in AWS Secrets Manager
- ✅ S3 Data Lake with encryption and lifecycle policies

Coming in future tasks:
- ⏳ Cold Path pipeline (Task 2)
- ⏳ Hot Path pipeline (Task 5)
- ⏳ Scrubber Path pipeline (Task 6)
- ⏳ OpenSearch and Neptune (Task 4)
- ⏳ Dashboard (Tasks 7-8)
- ⏳ Monitoring (Task 10)

## Verify Deployment

```bash
# Check outputs
terraform output

# Verify S3 bucket
aws s3 ls | grep synoptik

# Verify Secrets Manager
aws secretsmanager list-secrets | grep github-api-token

# Verify IAM roles
aws iam list-roles | grep github-dt
```

## Common Commands

```bash
# View current state
terraform show

# List all resources
terraform state list

# Get specific output
terraform output data_lake_bucket_name

# Refresh state
terraform refresh -var-file=environments/dev/terraform.tfvars

# Destroy everything (careful!)
make destroy-dev
```

## Environment Switching

### Switch to Staging
```bash
make init-staging
make plan-staging
make apply-staging
```

### Switch to Production
```bash
make init-prod
make plan-prod
make apply-prod
```

## Troubleshooting

### "Backend initialization failed"
```bash
# Ensure backend resources exist
make setup-backend-dev
```

### "github_token variable not set"
```bash
# Set the environment variable
export TF_VAR_github_token="your_token"
```

### "Access Denied" errors
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions
aws iam get-user
```

### "Module not found" errors
```bash
# Re-initialize Terraform
terraform init -upgrade
```

## Next Steps

After Task 1 is complete:
1. Proceed to Task 2: Implement Cold Path pipeline
2. Deploy CrawlerLambda and DynamoDB state table
3. Test with small dataset (1,000 repos)
4. Continue with remaining tasks

## Cost Estimate (Task 1 Only)

Current deployment costs (monthly):
- S3 Data Lake: ~$0.50 (minimal storage)
- Secrets Manager: ~$0.40 (1 secret)
- DynamoDB (on-demand): ~$0.00 (no traffic yet)

**Total: ~$1/month** for foundational infrastructure

Full system costs will increase with:
- Lambda executions
- OpenSearch cluster (~$200-500/month)
- Neptune cluster (~$300-600/month)
- Kinesis streams (~$50-100/month)

## Support

For issues or questions:
1. Check [README.md](README.md) for detailed documentation
2. Review [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for architecture
3. Examine Terraform plan output for specific errors
4. Check AWS CloudWatch Logs for runtime issues

## Clean Up

To remove all infrastructure:
```bash
make destroy-dev
```

**Warning**: This is irreversible and will delete all data!
