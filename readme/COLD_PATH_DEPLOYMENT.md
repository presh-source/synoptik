# Cold Path Deployment Guide

This guide walks through deploying the Cold Path pipeline for the Synoptik project.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **GitHub Personal Access Token** with `public_repo` scope
3. **Terraform** >= 1.5.0 installed
4. **AWS CLI** configured with credentials

## Deployment Steps

### 1. Set Up Backend (First Time Only)

```bash
cd terraform
./scripts/setup-backend.sh
```

This creates the S3 bucket and DynamoDB table for Terraform state management.

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region    = "us-east-1"
environment   = "dev"
github_token  = "ghp_your_token_here"  # Replace with your token
vpc_cidr      = "10.0.0.0/16"
```

**Important**: Never commit `terraform.tfvars` to version control!

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

Review the resources that will be created:
- S3 Data Lake bucket with Glue Catalog
- DynamoDB CrawlState table
- Lambda function with IAM role
- EventBridge rule
- CloudWatch alarms and SNS topic

### 5. Deploy

```bash
terraform apply
```

Type `yes` when prompted to confirm.

## Verify Deployment

### Check Lambda Function

```bash
aws lambda get-function --function-name dev-synoptik-crawler
```

### Check DynamoDB Table

```bash
aws dynamodb describe-table --table-name dev-synoptik-crawler-state
```

### Check Initial Bookmark

```bash
aws dynamodb get-item \
  --table-name dev-synoptik-crawler-state \
  --key '{"state_key": {"S": "bookmark"}}'
```

Should return:
```json
{
  "state_key": "bookmark",
  "last_processed_id": 0,
  "total_processed": 0,
  "updated_at": "2025-11-10T..."
}
```

### Check EventBridge Rule

```bash
aws events describe-rule --name dev-synoptik-crawler-schedule
```

## Manual Testing

### Invoke Lambda Manually

```bash
aws lambda invoke \
  --function-name dev-synoptik-crawler \
  --payload '{}' \
  response.json

cat response.json
```

### Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/dev-synoptik-crawler --follow
```

### Monitor Progress

```bash
# Check bookmark after execution
aws dynamodb get-item \
  --table-name dev-synoptik-crawler-state \
  --key '{"state_key": {"S": "bookmark"}}' \
  --query 'Item.last_processed_id.N'
```

### Check S3 Data

```bash
aws s3 ls s3://dev-synoptik-data-lake/cold-path/ --recursive
```

## Subscribe to Alerts

Subscribe your email to the SNS topic to receive alerts:

```bash
aws sns subscribe \
  --topic-arn $(terraform output -raw cold_path_sns_topic_arn) \
  --protocol email \
  --notification-endpoint your-email@example.com
```

Confirm the subscription via the email you receive.

## Monitoring

### CloudWatch Dashboard

View metrics in the AWS Console:
1. Go to CloudWatch > Dashboards
2. Look for custom metrics under `Synoptik/ColdPath`

### Key Metrics to Monitor

- **CrawlerProgress**: Should increment every 15 minutes
- **RepositoriesProcessed**: Total repos fetched per execution
- **Lambda Errors**: Should be 0 or very low
- **Lambda Duration**: Should be close to 900 seconds (15 min)

### Check Rate Limit Status

Look for rate limit info in CloudWatch Logs:
```
Rate limit remaining: 4500, resets at: 1699564800
```

## Troubleshooting

### Lambda Fails with "Rate Limit Exceeded"

The crawler includes exponential backoff, but if you see persistent rate limit errors:
1. Check if another process is using the same GitHub token
2. Reduce `requests_per_execution` in variables
3. Increase `sleep_interval` to slow down requests

### No Progress After Multiple Executions

Check CloudWatch Logs for errors:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/dev-synoptik-crawler \
  --filter-pattern "ERROR"
```

### DynamoDB Bookmark Not Updating

Ensure Lambda has proper IAM permissions:
```bash
aws iam get-role-policy \
  --role-name dev-synoptik-crawler-lambda \
  --policy-name dev-synoptik-crawler-lambda-policy
```

### S3 Write Failures

Check S3 bucket permissions and ensure Lambda role has `s3:PutObject` permission.

## Pause/Resume Crawl

### Pause

Disable the EventBridge rule:
```bash
aws events disable-rule --name dev-synoptik-crawler-schedule
```

### Resume

Enable the EventBridge rule:
```bash
aws events enable-rule --name dev-synoptik-crawler-schedule
```

The crawler will automatically resume from the last bookmark.

## Cost Estimation

### Per Day (Approximate)
- **Lambda**: ~96 executions/day × 15 min × $0.0000166667/GB-second ≈ $1.20
- **DynamoDB**: On-demand, minimal cost ≈ $0.01
- **S3**: ~10 GB/day × $0.023/GB ≈ $0.23
- **CloudWatch**: Logs and metrics ≈ $0.50

**Total**: ~$2/day or ~$60/month during active crawl

### Full Crawl (48 days)
- **Total Cost**: ~$96 for complete 500M repository crawl

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all data in S3 and DynamoDB!

## Next Steps

After the Cold Path is deployed and running:
1. Monitor progress for 24 hours to ensure stability
2. Deploy the Hot Path pipeline for real-time updates
3. Deploy query engines (OpenSearch, Neptune, Athena)
4. Set up the observability dashboard
