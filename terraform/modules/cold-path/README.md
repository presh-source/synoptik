# Cold Path Module

This module implements the Cold Path pipeline for the Synoptik project. It crawls the complete historical baseline of 500M+ repositories from the GitHub API.

## Components

### DynamoDB Table
- **Name**: `{environment}-synoptik-crawler-state`
- **Purpose**: Stores the crawler bookmark (last processed repository ID)
- **Billing**: On-demand capacity
- **Features**: Point-in-time recovery, server-side encryption

### Lambda Function
- **Name**: `{environment}-synoptik-crawler`
- **Runtime**: Python 3.11
- **Memory**: 512 MB (configurable)
- **Timeout**: 15 minutes (900 seconds)
- **Concurrency**: 1 (serial execution)

### EventBridge Rule
- **Schedule**: Every 15 minutes
- **Purpose**: Triggers the CrawlerLambda function

### CloudWatch Alarms
- **Errors**: Alerts when Lambda has >3 errors in 30 minutes
- **Throttles**: Alerts when Lambda is throttled
- **Stalled**: Alerts when no progress is made in 30 minutes

## Features

### Modern Stack
- **AWS Lambda Powertools**: Structured logging, tracing, and metrics
- **Parquet Format**: Columnar storage with Snappy compression (10x smaller than JSON)
- **Pandas & PyArrow**: Efficient data transformation and serialization

### Rate Limiting
- Executes 1,050 API requests per 15-minute window
- Maintains 4,500 requests/hour rate (within GitHub's 5,000/hour limit)
- 0.8 second pacing between requests

### Error Handling
- Exponential backoff retry for API failures (up to 3 retries)
- Timeout monitoring (stops 30 seconds before Lambda timeout)
- Comprehensive CloudWatch logging
- SNS alerts for critical failures

### Data Storage
- Saves data to S3 in Parquet format with Snappy compression
- Partitioned by year/month/day
- Batch writes every 10 requests (~1000 repos)
- Columnar format for efficient querying with Athena

### Observability
- AWS Lambda Powertools for structured logging
- Distributed tracing with X-Ray
- Custom CloudWatch metrics for monitoring
- Automatic cold start tracking

### State Management
- Reads bookmark once at startup
- Updates bookmark synchronously at end of execution
- Ensures resumability after failures

## Usage

```hcl
module "cold_path" {
  source = "./modules/cold-path"
  
  environment           = "dev"
  github_token_arn      = "arn:aws:secretsmanager:..."
  data_lake_bucket_name = "dev-synoptik-data-lake"
  
  # Optional overrides
  requests_per_execution = 1050
  sleep_interval         = 0.8
  lambda_timeout         = 900
  lambda_memory          = 512
}
```

## Outputs

- `dynamodb_table_name`: Name of the CrawlState table
- `dynamodb_table_arn`: ARN of the CrawlState table
- `crawler_lambda_arn`: ARN of the Lambda function
- `crawler_lambda_name`: Name of the Lambda function
- `eventbridge_rule_arn`: ARN of the EventBridge rule
- `sns_topic_arn`: ARN of the SNS topic for alerts

## Monitoring

### CloudWatch Metrics
- `AWS/Lambda/Errors`: Lambda execution errors
- `AWS/Lambda/Throttles`: Lambda throttling events
- `Synoptik/ColdPath/CrawlerProgress`: Successful crawl completions
- `Synoptik/ColdPath/RepositoriesProcessed`: Number of repos processed

### CloudWatch Logs
- Log Group: `/aws/lambda/{environment}-synoptik-crawler`
- Retention: 30 days
- Includes: API responses, rate limits, errors, state transitions

## Requirements

- GitHub Personal Access Token stored in AWS Secrets Manager
- S3 bucket for data lake (created by data-lake module)
- IAM permissions for Lambda to access DynamoDB, S3, and Secrets Manager

## Estimated Timeline

- **Total Repositories**: 500,000,000
- **Rate**: 4,500 repos/hour
- **Duration**: ~48 days for complete crawl
