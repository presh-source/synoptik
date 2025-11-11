# Synoptik Naming Convention Update

All AWS resources have been updated to use "synoptik" instead of "synoptik" for consistent branding.

## Updated Resource Names

### S3 Buckets
- **Before**: `{environment}-synoptik-data-lake`
- **After**: `{environment}-synoptik-data-lake`

### DynamoDB Tables
- **Before**: `{environment}-github-crawler-state`
- **After**: `{environment}-synoptik-crawler-state`

### Lambda Functions
- **Before**: `{environment}-github-crawler`
- **After**: `{environment}-synoptik-crawler`

### IAM Roles
- **Before**: `{environment}-github-dt-*`
- **After**: `{environment}-synoptik-*`
  - `synoptik-lambda-execution`
  - `synoptik-glue-execution`
  - `synoptik-eventbridge`
  - `synoptik-firehose`
  - `synoptik-crawler-lambda`

### EventBridge Rules
- **Before**: `{environment}-github-crawler-schedule`
- **After**: `{environment}-synoptik-crawler-schedule`

### CloudWatch Resources
- **Log Groups**: `/aws/lambda/{environment}-synoptik-crawler`
- **Alarms**: 
  - `{environment}-synoptik-crawler-errors`
  - `{environment}-synoptik-crawler-throttles`
  - `{environment}-synoptik-crawler-stalled`
- **Metrics Namespace**: `Synoptik/ColdPath` (was `GitHubDigitalTwin/ColdPath`)

### SNS Topics
- **Before**: `{environment}-github-crawler-alerts`
- **After**: `{environment}-synoptik-crawler-alerts`

### Secrets Manager
- **Before**: `{environment}-github-api-token`
- **After**: `{environment}-synoptik-github-token`

### Glue Data Catalog
- **Database**: `{environment}_synoptik` (was `{environment}_github_digital_twin`)
- **Tables**: `repositories` (unchanged)

### Lambda User-Agent
- **Before**: `Synoptik-Crawler`
- **After**: `Synoptik-Crawler`

## Files Updated

### Terraform Modules
- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/modules/data-lake/main.tf`
- `terraform/modules/data-lake/outputs.tf`
- `terraform/modules/cold-path/main.tf`
- `terraform/modules/cold-path/lambda/crawler.py`
- `terraform/modules/iam/main.tf`
- `terraform/modules/secrets/main.tf`

### Documentation
- `terraform/modules/cold-path/README.md`
- `terraform/COLD_PATH_DEPLOYMENT.md`
- `terraform/TASK_2_COMPLETION.md`

## Migration Notes

If you have already deployed infrastructure with the old naming convention:

1. **Option 1: Destroy and Recreate** (Recommended for dev/test)
   ```bash
   terraform destroy
   terraform apply
   ```
   **Warning**: This will delete all data!

2. **Option 2: Terraform State Migration** (For production)
   Use `terraform state mv` to rename resources without recreating them:
   ```bash
   # Example for DynamoDB table
   terraform state mv \
     'module.cold_path.aws_dynamodb_table.crawl_state' \
     'module.cold_path.aws_dynamodb_table.crawl_state'
   ```
   Then manually rename AWS resources in the console or via AWS CLI.

3. **Option 3: Fresh Deployment** (Cleanest)
   Deploy to a new environment with the updated naming.

## Validation

All Terraform configurations have been validated:
```bash
terraform fmt -recursive  # ✅ Passed
terraform validate        # ✅ Passed
```

## Impact

- **Breaking Change**: Yes, resource names have changed
- **Data Loss Risk**: High if using destroy/recreate
- **Recommended Action**: Deploy to new environment or use state migration
- **Backward Compatibility**: None (new names required)

## Benefits

- Consistent branding with project name "Synoptik"
- Clearer resource identification in AWS Console
- Shorter, more memorable resource names
- Better alignment with project identity
