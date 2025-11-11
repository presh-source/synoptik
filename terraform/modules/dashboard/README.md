# Dashboard Module

This module implements the observability dashboard backend API for the Synoptik platform.

## Overview

The dashboard module provides REST API endpoints for monitoring and querying the status of all three pipelines (Cold Path, Hot Path, and Scrubber Path) as well as real-time metrics from OpenSearch.

## Architecture

### API Gateway Endpoints

- `GET /api/pipeline-status` - Returns status of all three pipelines
- `GET /api/metrics/realtime` - Returns real-time metrics from OpenSearch
- `GET /api/metrics/trending` - Returns trending repositories
- `GET /api/metrics/cloudwatch` - Returns CloudWatch metrics for all pipelines

### Lambda Functions

1. **Pipeline Status Lambda** (`pipeline_status.py`)
   - Queries DynamoDB for Cold Path bookmark
   - Queries Kinesis for Hot Path metrics
   - Queries SQS for Scrubber Path queue depth
   - Calculates ingestion rates and progress percentages

2. **Realtime Metrics Lambda** (`realtime_metrics.py`)
   - Queries OpenSearch for trending repositories
   - Aggregates repositories by language and license
   - Provides time-series data for repository creation trends
   - Supports filtering by language, license, and date range

3. **CloudWatch Metrics Lambda** (`cloudwatch_metrics.py`)
   - Fetches CloudWatch metrics for all Lambda functions
   - Calculates error rates and API request rates
   - Monitors Lambda execution metrics and throttling
   - Provides overall system health metrics

## Features

### CORS Support

All endpoints include CORS headers to allow cross-origin requests from the frontend application.

### API Throttling

API Gateway is configured with:
- Burst limit: 500 requests
- Rate limit: 1000 requests per second

### IAM Permissions

Each Lambda function has least-privilege IAM policies:
- Pipeline Status: DynamoDB read, Kinesis describe, SQS read, CloudWatch read
- Realtime Metrics: OpenSearch read
- CloudWatch Metrics: CloudWatch read, Lambda describe

## Usage

### Deploying the Module

```hcl
module "dashboard" {
  source = "./modules/dashboard"
  
  environment               = var.environment
  opensearch_endpoint       = module.data_stores.opensearch_endpoint
  neptune_endpoint          = module.data_stores.neptune_endpoint
  cold_path_dynamodb_table  = module.cold_path.dynamodb_table_name
  kinesis_stream_name       = module.hot_path.kinesis_stream_name
  scrubber_queue_url        = module.scrubber_path.sqs_queue_url
}
```

### API Examples

#### Get Pipeline Status

```bash
curl https://api-gateway-url/dev/api/pipeline-status
```

Response:
```json
{
  "cold_path": {
    "status": "running",
    "last_processed_id": 1234567,
    "total_processed": 1234567,
    "ingestion_rate": 10500.0,
    "progress_percentage": 0.2469,
    "estimated_completion_hours": 1152.0
  },
  "hot_path": {
    "status": "active",
    "events_per_minute": 150.5,
    "kinesis_lag_ms": 250.0
  },
  "scrubber_path": {
    "status": "running",
    "queue_depth": 50000,
    "validation_rate": 100.0
  }
}
```

#### Get Trending Repositories

```bash
curl https://api-gateway-url/dev/api/metrics/trending
```

Response:
```json
{
  "trending_repositories": [
    {
      "id": 123456,
      "full_name": "owner/repo",
      "description": "A trending repository",
      "language": "Python",
      "stargazers_count": 5000,
      "forks_count": 500,
      "watchers_count": 5000
    }
  ]
}
```

#### Get Real-Time Metrics with Filters

```bash
curl "https://api-gateway-url/dev/api/metrics/realtime?language=Python&startDate=2025-10-01&endDate=2025-11-10"
```

Response:
```json
{
  "total_repositories": 1500000,
  "repositories_by_language": {
    "Python": 1500000
  },
  "repositories_by_license": {
    "MIT": 800000,
    "Apache-2.0": 400000
  },
  "creation_trends": [
    {"date": "2025-10-01", "count": 1500},
    {"date": "2025-10-02", "count": 1600}
  ]
}
```

#### Get CloudWatch Metrics

```bash
curl https://api-gateway-url/dev/api/metrics/cloudwatch
```

Response:
```json
{
  "cold_path": {
    "error_rate": 0.5,
    "api_request_rate": 4500.0,
    "lambda_duration_ms": 850.0,
    "lambda_throttles": 0
  },
  "hot_path": {
    "error_rate": 1.2,
    "event_processing_rate": 150.0,
    "kinesis_incoming_records": 9000
  },
  "scrubber_path": {
    "error_rate": 0.1,
    "validation_rate": 100.0
  },
  "overall": {
    "total_lambda_functions": 6,
    "total_invocations": 50000,
    "total_errors": 250,
    "overall_error_rate": 0.5
  }
}
```

## Lambda Dependencies

The Lambda functions require the following Python packages (see `requirements.txt`):
- `boto3` - AWS SDK
- `opensearch-py` - OpenSearch client
- `requests-aws4auth` - AWS authentication for OpenSearch

## Outputs

- `api_gateway_url` - The invoke URL for the API Gateway
- `api_gateway_id` - The ID of the API Gateway REST API
- `pipeline_status_lambda_arn` - ARN of the pipeline status Lambda
- `realtime_metrics_lambda_arn` - ARN of the realtime metrics Lambda
- `cloudwatch_metrics_lambda_arn` - ARN of the CloudWatch metrics Lambda

## Monitoring

CloudWatch Logs are configured for all Lambda functions with 30-day retention.

## Security

- All Lambda functions use IAM roles with least-privilege permissions
- API Gateway endpoints are currently open (no authentication)
- CORS is enabled for all endpoints
- All data in transit is encrypted via HTTPS

## Future Enhancements

- Add AWS Cognito authentication for API endpoints
- Implement caching with API Gateway cache
- Add request/response validation
- Implement rate limiting per API key
- Add WebSocket support for real-time updates
