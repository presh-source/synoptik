# AppSync Lambda Data Sources

This directory contains Lambda functions that serve as data sources for AppSync GraphQL resolvers.

## Lambda Functions

### 1. pipeline_status_resolver.py
**Purpose**: Resolves the `pipelineStatus` query in the GraphQL schema.

**Functionality**:
- Fetches Cold Path pipeline status including crawler metrics
- Retrieves bookmarks from DynamoDB
- Fetches CloudWatch metrics for both repo and user crawlers
- Calculates error rates from Lambda metrics

**Event Structure**:
```json
{
  "field": "pipelineStatus",
  "arguments": {}
}
```

**Returns**: Complete pipeline status with cold path data and error rates

### 2. crawler_metrics_resolver.py
**Purpose**: Resolves the `repoCrawler` and `userCrawler` queries in the GraphQL schema.

**Functionality**:
- Fetches metrics for a specific crawler type (repo or user)
- Retrieves bookmark data from DynamoDB
- Fetches CloudWatch metrics for the specified crawler
- Calculates crawl rates (per hour, per minute, per second)

**Event Structure**:
```json
{
  "field": "repoCrawler" | "userCrawler",
  "crawlerType": "repo" | "user",
  "timePeriodHours": 1
}
```

**Returns**: Crawler-specific metrics with rates and counts

### 3. error_rates_resolver.py
**Purpose**: Resolves the `errorRates` query in the GraphQL schema.

**Functionality**:
- Fetches error metrics from CloudWatch for Lambda functions
- Calculates error rate as percentage (errors / invocations * 100)

**Event Structure**:
```json
{
  "field": "errorRates",
  "arguments": {}
}
```

**Returns**: Error rates for the Cold Path pipeline

## Business Logic Reuse

All three Lambda functions reuse the same business logic from the existing REST API Lambda functions:
- `get_crawler_metrics_from_cloudwatch()` - Fetches CloudWatch metrics
- `get_bookmark()` - Retrieves DynamoDB bookmarks
- `get_cold_path_status()` - Aggregates cold path status
- `get_error_rates()` - Calculates error rates

This ensures consistency between the REST API and GraphQL API.

## Environment Variables

All Lambda functions require:
- `DYNAMODB_TABLE_NAME` - DynamoDB table for bookmarks
- `PROJECT_NAME` - Project name for CloudWatch namespace
- `ENVIRONMENT` - Environment name (dev, staging, prod)

## IAM Permissions

Each Lambda function has permissions to:
- Read from DynamoDB (GetItem, Query)
- Read CloudWatch metrics (GetMetricStatistics, ListMetrics)

## AppSync Integration

AppSync invokes these Lambda functions through:
1. **IAM Role**: AppSync assumes a role with `lambda:InvokeFunction` permission
2. **Lambda Permissions**: Each Lambda grants AppSync permission to invoke it
3. **VTL Templates**: AppSync uses VTL templates to map GraphQL requests to Lambda events

## Deployment

These Lambda functions are deployed via Terraform in `backend/modules/appsync/main.tf`.
