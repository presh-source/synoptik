# Design Document

## Overview

The GitHub Digital Twin platform is a distributed, event-driven system that creates a complete replica of the public GitHub ecosystem. The architecture consists of three independent pipelines that work in concert to provide historical baseline data, real-time updates, and data quality maintenance. The system leverages AWS managed services to achieve scalability, durability, and cost-effectiveness.

### Architecture Principles

1. **Separation of Concerns**: Three independent pipelines (Cold, Hot, Scrubber) operate without blocking each other
2. **Event-Driven Design**: Real-time updates flow through Kinesis for fan-out to multiple consumers
3. **Polyglot Persistence**: Three specialized query engines optimized for different access patterns
4. **Idempotency**: All data ingestion operations are designed to be safely retryable
5. **Cost Optimization**: S3 + Athena for cold storage, OpenSearch for hot queries, Neptune for graph traversals

## Architecture

### High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                             GitHub API                              │
│                                                                     │
│  /repositories (Cold)   │  /events (Hot)   │  /repos/{owner}/{repo} │
└────────┬────────────────┴────────┬─────────┴───────────┬────────────┘
         │                         │                     │
         │                         │                     │ 
         ▼                         ▼                     ▼
      Cold Path               Hot Path            Scrubber Path
┌────────────────┐        ┌────────────────┐   ┌─────────────────┐
│ EventBridge    │        │ EventsPoller   │   │ Feeder Glue Job │
│ (15 min cron)  │        │ Lambda         │   │ (Weekly)        │
└───────┬────────┘        └───────┬────────┘   └────────┬────────┘
        │                         │                     │
        ▼                         ▼                     ▼
┌────────────────┐        ┌────────────────┐   ┌────────────────┐
│ CrawlerLambda  │        │ Kinesis Data   │   │ SQS Queue      │
│                │        │ Stream         │   │                │
└───────┬────────┘        └───┬────────┬───┘   └───────┬────────┘
        │                     │        │               │
        │                     │        │               ▼
        ▼                     ▼        ▼      ┌────────────────┐
┌────────────────┐   ┌─────────┐  ┌─────────┐ │ PingerLambda   │
│ S3 Data Lake   │   │Firehose │  │ Graph   │ │                │
│ (Raw JSON.gz)  │   │         │  │ Updater │ └───────┬────────┘
└───────┬────────┘   └────┬────┘  └────┬────┘         │
        │                 │            │              │
        │                 ▼            ▼              │
        │         ┌──────────────────────┐            │
        │         │   Amazon OpenSearch  │◄───────────┤
        │         └──────────────────────┘            │
        │                                             │
        │         ┌──────────────────────┐            │
        │         │   Amazon Neptune     │◄───────────┘
        │         └──────────────────────┘
        │
        ▼
┌────────────────┐
│ AWS Glue Job   │──────────────────────────────────┐
│ (Bulk Load)    │                                  │
└────────────────┘                                  │
        │                                           │
        └───────────────────┬───────────────────────┘
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
        ┌──────────────┐        ┌──────────────┐
        │ OpenSearch   │        │   Neptune    │
        └──────────────┘        └──────────────┘
                │                       │
                └───────────┬───────────┘
                            ▼
                ┌───────────────────────┐
                │ Observability         │
                │ Dashboard (React)     │
                └───────────────────────┘
```


## Components and Interfaces

### Cold Path Components

#### 1. EventBridge Cron Rule
- **Purpose**: Orchestrates the CrawlerLambda execution every 15 minutes
- **Configuration**: `rate(15 minutes)` schedule expression
- **Target**: CrawlerLambda function
- **State**: Stateless orchestrator

#### 2. CrawlerLambda
- **Runtime**: Python 3.11
- **Memory**: 512 MB
- **Timeout**: 15 minutes (900 seconds)
- **Concurrency**: 1 (serial execution required)
- **Environment Variables**:
  - `DYNAMODB_TABLE_NAME`: Name of the CrawlState table
  - `S3_BUCKET_NAME`: Target bucket for raw JSON storage
  - `GITHUB_TOKEN`: Personal access token for API authentication
  - `REQUESTS_PER_EXECUTION`: 1050
  - `SLEEP_INTERVAL`: 0.8 seconds

**Key Methods**:
```python
def lambda_handler(event, context):
    # Entry point for Lambda execution
    
def get_last_processed_id() -> int:
    # Reads bookmark from DynamoDB once at startup
    
def crawl_repositories(start_id: int, num_requests: int) -> int:
    # Executes fixed loop of API requests with pacing
    
def save_to_s3(data: dict, repo_id: int):
    # Saves compressed JSON to S3 with partitioning
    
def update_bookmark(last_id: int):
    # Synchronously updates DynamoDB at end of execution
```

**API Integration**:
- Endpoint: `GET https://api.github.com/repositories?since={id}`
- Rate Limit: 5,000 requests/hour (using authenticated token)
- Response: Array of up to 100 repository objects per request
- Pagination: Uses `since` parameter for serial traversal

#### 3. DynamoDB CrawlState Table
- **Table Name**: `github-crawler-state`
- **Primary Key**: `state_key` (String) - Fixed value: "bookmark"
- **Attributes**:
  - `last_processed_id` (Number): The last successfully processed repository ID
  - `updated_at` (String): ISO timestamp of last update
  - `total_processed` (Number): Running count of repositories processed
- **Capacity**: On-demand billing mode
- **Consistency**: Strong consistency for read operations

#### 4. S3 Data Lake
- **Bucket Structure**:
```
s3://synoptik-data-lake/
  ├── cold-path/
  │   ├── year=2025/
  │   │   ├── month=11/
  │   │   │   ├── day=10/
  │   │   │   │   ├── repos_000000001_000100000.json.gz
  │   │   │   │   ├── repos_000100001_000200000.json.gz
  │   │   │   │   └── ...
  ├── hot-path/
  │   ├── year=2025/
  │   │   ├── month=11/
  │   │   │   ├── day=10/
  │   │   │   │   ├── hour=14/
  │   │   │   │   │   ├── events_20251110_140000.json.gz
```
- **Compression**: gzip compression for all JSON files
- **Lifecycle Policy**: Transition to S3 Glacier after 90 days for cold-path data
- **Versioning**: Disabled (immutable append-only writes)

#### 5. AWS Glue Bulk Load Job
- **Purpose**: One-time transformation and bulk load of Cold Path data
- **Trigger**: Manual execution after Cold Path completes
- **Steps**:
  1. Read raw JSON from S3 using Glue DynamicFrame
  2. Transform to unified data model schema
  3. Bulk load to OpenSearch using opensearch-py
  4. Bulk load to Neptune using Gremlin bulk loader
- **Parallelism**: 50 DPU (Data Processing Units)

### Hot Path Components

#### 1. EventsPoller Lambda
- **Runtime**: Python 3.11
- **Memory**: 256 MB
- **Timeout**: 60 seconds
- **Trigger**: EventBridge cron `rate(1 minute)`
- **Environment Variables**:
  - `KINESIS_STREAM_NAME`: Target stream for events
  - `GITHUB_TOKEN`: API authentication token

**Key Methods**:
```python
def lambda_handler(event, context):
    # Polls /events and publishes to Kinesis
    
def fetch_events() -> List[dict]:
    # Calls GitHub /events API
    
def publish_to_kinesis(events: List[dict]):
    # Batch writes to Kinesis stream
    # Includes event ID in partition key for natural deduplication
```

**Deduplication Strategy**: Instead of using ElastiCache Redis (which adds cost and complexity), we rely on idempotent consumers:
- **Neptune GraphUpdater**: Uses Gremlin `fold().coalesce()` pattern to prevent duplicate edges
- **OpenSearch Firehose**: Document updates are naturally idempotent (updating the same field twice with the same value has no effect)
- **Event ID as Partition Key**: Using event ID in the Kinesis partition key provides natural ordering and helps downstream consumers detect duplicates if needed

**Rationale**: Idempotent consumers eliminate the need for a separate deduplication layer. This reduces infrastructure complexity, cost, and potential failure points. If duplicate events are processed, they result in the same final state.

**API Integration**:
- Endpoint: `GET https://api.github.com/events`
- Rate Limit: 5,000 requests/hour
- Response: Array of up to 300 events
- Polling Strategy: Every 60 seconds to capture all public events

#### 2. Kinesis Data Stream
- **Stream Name**: `github-events-stream`
- **Shard Count**: 10 shards (scalable based on throughput)
- **Retention Period**: 24 hours
- **Partition Key**: `event.repo.id` for even distribution
- **Consumers**:
  - Kinesis Data Firehose (OpenSearch delivery)
  - GraphUpdater Lambda (Neptune updates)

#### 3. Kinesis Data Firehose
- **Delivery Stream Name**: `github-events-to-opensearch`
- **Source**: Kinesis Data Stream
- **Destination**: Amazon OpenSearch cluster
- **Buffer Settings**:
  - Size: 5 MB
  - Interval: 60 seconds
- **Transformation**: Lambda function for event-to-document mapping
- **Error Handling**: Failed records sent to S3 error bucket

**Transformation Lambda**:
```python
def transform_event_to_opensearch_update(event: dict) -> dict:
    # Maps event type to OpenSearch update operation
    # Returns: {"_index": "repositories", "_id": repo_id, "doc": {...}}
```

#### 4. GraphUpdater Lambda
- **Runtime**: Python 3.11
- **Memory**: 1024 MB
- **Timeout**: 5 minutes
- **Trigger**: Kinesis Data Stream (batch size: 100 records)
- **Environment Variables**:
  - `NEPTUNE_ENDPOINT`: Neptune cluster endpoint
  - `NEPTUNE_PORT`: 8182

**Key Methods**:
```python
def lambda_handler(event, context):
    # Processes batch of Kinesis records
    
def translate_event_to_gremlin(event: dict) -> str:
    # Converts event to Gremlin query
    
def execute_gremlin_batch(queries: List[str]):
    # Executes batch of Gremlin queries against Neptune
```

**Event-to-Gremlin Mapping (Idempotent)**:
- `WatchEvent` → `g.V(user_id).as('u').V(repo_id).as('r').coalesce(__.inE('STARRED').where(outV().as('u')), __.addE('STARRED').from('u').property('timestamp', event_time))`
- `ForkEvent` → `g.V(user_id).as('u').V(repo_id).as('r').coalesce(__.inE('FORKED').where(outV().as('u')), __.addE('FORKED').from('u').property('timestamp', event_time))`
- `PushEvent` → `g.V(user_id).as('u').V(repo_id).as('r').coalesce(__.inE('COMMITTED_TO').where(outV().as('u')), __.addE('COMMITTED_TO').from('u').property('timestamp', event_time))`
- `IssuesEvent` → Similar idempotent pattern using `coalesce()` to check for existing edges before creating new ones

**Idempotency Pattern**: The `coalesce()` pattern checks if an edge already exists before creating it. This ensures that processing the same event multiple times does not create duplicate edges, eliminating the need for external deduplication infrastructure.

### Scrubber Path Components

#### 1. Feeder Glue Job
- **Job Type**: AWS Glue Python Shell (or Spark for larger scale)
- **Python Version**: 3.9
- **DPU**: 1 DPU for Python Shell (or 10 DPU for Spark)
- **Timeout**: 48 hours (sufficient for 500M repositories)
- **Trigger**: EventBridge cron `rate(7 days)`
- **Environment Variables**:
  - `ATHENA_DATABASE`: Glue catalog database name
  - `SQS_QUEUE_URL`: Target queue for repository names
  - `BATCH_SIZE`: 10 messages per SQS batch

**Key Implementation**:
```python
# Glue job script
import boto3
from awsglue.utils import getResolvedOptions
import sys

def main():
    # Read from Athena/S3 using Glue DynamicFrame
    # Iterate through 500M repositories in batches
    # Send batches of 10 to SQS
    # Process runs for hours/days as needed
    
def batch_send_to_sqs(repo_names: List[str]):
    # Sends batches of 10 messages to SQS
    # Handles throttling and retries
```

**Rationale**: A Lambda's 15-minute timeout cannot handle querying and iterating through 500M repositories. AWS Glue can run for up to 48 hours and is designed for large-scale batch processing. The job will read from the S3 Data Lake (via Athena or directly), iterate through all repositories, and populate the SQS queue over several hours or days.

#### 2. SQS Queue
- **Queue Name**: `github-scrubber-queue`
- **Type**: Standard queue
- **Visibility Timeout**: 300 seconds
- **Message Retention**: 14 days
- **Dead Letter Queue**: `github-scrubber-dlq` (after 3 receive attempts)
- **Batch Size**: 10 messages per Lambda invocation

#### 3. PingerLambda
- **Runtime**: Python 3.11
- **Memory**: 256 MB
- **Timeout**: 5 minutes
- **Trigger**: SQS Queue
- **Concurrency**: 10 (rate-limited)
- **Environment Variables**:
  - `GITHUB_TOKEN`: API authentication
  - `OPENSEARCH_ENDPOINT`: OpenSearch cluster endpoint
  - `NEPTUNE_ENDPOINT`: Neptune cluster endpoint

**Key Methods**:
```python
def lambda_handler(event, context):
    # Processes batch of SQS messages
    
def check_repository_exists(full_name: str) -> bool:
    # Calls GET /repos/{owner}/{repo}
    
def mark_as_deleted_opensearch(repo_id: int):
    # Deletes document from OpenSearch
    
def mark_as_deleted_neptune(repo_id: int):
    # Executes g.V(repo_id).drop()
```


### Query Engine Components

#### 1. Amazon Athena
- **Purpose**: SQL queries on cold storage (S3 Data Lake)
- **Database**: `github_digital_twin`
- **Tables**:
  - `repositories`: Partitioned by year/month/day
  - `events`: Partitioned by year/month/day/hour
- **Query Patterns**:
  - Historical trend analysis
  - Bulk exports for ML training
  - Ad-hoc exploratory queries
- **Cost Model**: Pay-per-query based on data scanned

#### 2. Amazon OpenSearch
- **Cluster Configuration**:
  - Instance Type: r6g.2xlarge.search (3 data nodes)
  - Storage: 2 TB EBS per node (gp3)
  - Dedicated Master: 3x m6g.large.search
- **Indices**:
  - `repositories`: Primary index with 10 shards
  - `events`: Time-series index with daily rollover
- **Mappings**:
```json
{
  "repositories": {
    "properties": {
      "id": {"type": "long"},
      "full_name": {"type": "keyword"},
      "description": {"type": "text"},
      "language": {"type": "keyword"},
      "license_name": {"type": "keyword"},
      "stargazers_count": {"type": "integer"},
      "forks_count": {"type": "integer"},
      "watchers_count": {"type": "integer"},
      "open_issues_count": {"type": "integer"},
      "created_at": {"type": "date"},
      "pushed_at": {"type": "date"},
      "is_deleted": {"type": "boolean"}
    }
  }
}
```

#### 3. Amazon Neptune
- **Cluster Configuration**:
  - Instance Type: db.r6g.2xlarge (3 instances)
  - Storage: Auto-scaling up to 64 TB
  - Read Replicas: 2 for query load distribution
- **Graph Model**:
  - Vertices: `User`, `Repository`, `Issue`
  - Edges: `OWNS`, `STARRED`, `FORKED`, `COMMITTED_TO`, `OPENED`, `BELONGS_TO`
- **Vertex Properties**:
  - `User`: `id`, `login`, `type`
  - `Repository`: `id`, `full_name`, `language`, `stargazers_count`
  - `Issue`: `id`, `title`, `state`, `created_at`
- **Query Patterns**:
  - Find all repos starred by a user
  - Find all contributors to a repo
  - Shortest path between two users
  - Community detection algorithms

### Observability Dashboard Components

#### 1. Frontend Application
- **Framework**: React 18 with TypeScript
- **UI Library**: Material-UI (MUI)
- **State Management**: React Query for server state
- **Charting**: Recharts for time-series visualizations
- **Hosting**: AWS Amplify or S3 + CloudFront

**Key Pages**:
- Pipeline Status Dashboard
- Real-Time Metrics Dashboard
- Repository Explorer
- Graph Visualization

#### 2. Backend API
- **Framework**: AWS API Gateway + Lambda (Python)
- **Endpoints**:
  - `GET /api/pipeline-status`: Returns Cold/Hot/Scrubber status
  - `GET /api/metrics/realtime`: Returns current event rates
  - `GET /api/repositories/trending`: Top repositories by stars
  - `GET /api/repositories/search`: Full-text search via OpenSearch
  - `GET /api/graph/query`: Execute Gremlin queries on Neptune

#### 3. CloudWatch Integration
- **Metrics**:
  - `ColdPath.RepositoriesProcessed`: Counter
  - `ColdPath.APIRequestRate`: Rate per minute
  - `HotPath.EventsProcessed`: Counter
  - `HotPath.KinesisLag`: Milliseconds behind
  - `Scrubber.RepositoriesValidated`: Counter
  - `Scrubber.DeletedRepositories`: Counter
- **Alarms**:
  - Cold Path stalled (no progress in 30 minutes)
  - Hot Path high error rate (>5% failures)
  - Kinesis iterator age >1 hour
  - Lambda throttling detected


## Data Models

### Repository Entity (Unified Model)

```python
@dataclass
class Repository:
    # Primary identifiers
    id: int                    # GitHub repository ID
    full_name: str             # owner/repo format
    
    # Content metadata
    description: Optional[str]
    language: Optional[str]
    license_name: Optional[str]
    
    # Analytics counters (updated by Hot Path)
    stargazers_count: int
    forks_count: int
    watchers_count: int
    open_issues_count: int
    
    # Timestamps
    created_at: datetime
    pushed_at: datetime
    
    # Internal state
    is_deleted: bool = False
    last_updated: datetime = field(default_factory=datetime.utcnow)
```

### User Entity

```python
@dataclass
class User:
    id: int                    # GitHub user ID
    login: str                 # Username
    type: str                  # "User" or "Organization"
    avatar_url: Optional[str]
```

### Issue Entity

```python
@dataclass
class Issue:
    id: int                    # GitHub issue ID
    number: int                # Issue number within repo
    title: str
    state: str                 # "open" or "closed"
    created_at: datetime
    repository_id: int         # Foreign key to Repository
```

### Event Entity (Hot Path)

```python
@dataclass
class GitHubEvent:
    id: str                    # Event ID
    type: str                  # Event type (PushEvent, WatchEvent, etc.)
    actor: User                # User who triggered the event
    repo: Repository           # Repository involved
    created_at: datetime
    payload: dict              # Event-specific data
```

### Graph Relationships

```python
# Ownership (from Cold Path)
(User) -[OWNS {since: datetime}]-> (Repository)

# Starring (from Hot Path WatchEvent)
(User) -[STARRED {timestamp: datetime}]-> (Repository)

# Forking (from Hot Path ForkEvent)
(User) -[FORKED {timestamp: datetime, fork_id: int}]-> (Repository)

# Commits (from Hot Path PushEvent)
(User) -[COMMITTED_TO {timestamp: datetime, commit_count: int}]-> (Repository)

# Issues (from Hot Path IssuesEvent)
(User) -[OPENED {timestamp: datetime}]-> (Issue)
(Issue) -[BELONGS_TO]-> (Repository)
```


## Error Handling

### Cold Path Error Handling

**API Request Failures**:
- **HTTP 403 (Rate Limit)**: Implement exponential backoff, wait and retry
- **HTTP 500 (Server Error)**: Retry up to 3 times with exponential backoff
- **Network Timeout**: Retry current request, do not advance bookmark
- **Strategy**: If any request in the batch fails after retries, log error and continue with next ID

**S3 Write Failures**:
- **PutObject Error**: Retry up to 3 times
- **Strategy**: If S3 write fails, do not update DynamoDB bookmark (ensures retry on next execution)

**DynamoDB Update Failures**:
- **ConditionalCheckFailed**: Log warning (indicates concurrent execution, should not happen)
- **ProvisionedThroughputExceeded**: Retry with exponential backoff
- **Strategy**: Critical operation - must succeed before Lambda exits

**Lambda Timeout**:
- **Approaching Timeout**: Monitor remaining execution time, stop processing 30 seconds before timeout
- **Strategy**: Update bookmark with last successful ID, allow next execution to continue

### Hot Path Error Handling

**EventsPoller Failures**:
- **API Rate Limit**: Back off and skip current poll cycle
- **Duplicate Events**: Handled by idempotent consumers (no Redis cache needed)
- **Kinesis PutRecords Failure**: Retry failed records up to 3 times

**Kinesis Stream Issues**:
- **ProvisionedThroughputExceeded**: Auto-scale shards or implement backpressure
- **Iterator Age Alarm**: Indicates consumer lag, scale up consumer Lambda concurrency

**Firehose Delivery Failures**:
- **OpenSearch Indexing Error**: Send failed records to S3 error bucket
- **Strategy**: Manual review and reprocessing of failed records

**GraphUpdater Failures**:
- **Gremlin Query Error**: Log error with event details, send to DLQ
- **Neptune Connection Timeout**: Retry with exponential backoff
- **Duplicate Edge Creation**: Use `fold().coalesce()` pattern to make operations idempotent

### Scrubber Path Error Handling

**PingerLambda Failures**:
- **HTTP 404 (Not Found)**: Expected case - mark repository as deleted
- **HTTP 403 (Forbidden)**: Repository is private - mark as deleted
- **HTTP 429 (Rate Limit)**: Return message to SQS for retry
- **Network Error**: Retry up to 3 times, then send to DLQ

**SQS Dead Letter Queue**:
- **Purpose**: Capture repositories that fail validation after 3 attempts
- **Processing**: Manual review or separate Lambda for special handling

**OpenSearch/Neptune Delete Failures**:
- **Document Not Found**: Log warning and continue (idempotent operation)
- **Connection Error**: Retry up to 3 times

### Cross-Cutting Error Handling

**Logging Strategy**:
- All errors logged to CloudWatch Logs with structured JSON format
- Include: `timestamp`, `component`, `error_type`, `error_message`, `context`
- Critical errors trigger SNS notifications to operations team

**Monitoring and Alerting**:
- CloudWatch Alarms for error rate thresholds
- Lambda error metrics tracked per function
- Custom metrics for business logic errors (e.g., API rate limit hits)

**Idempotency Patterns**:
- Cold Path: Bookmark-based resumption ensures no duplicate processing
- Hot Path: Event ID deduplication in Redis cache
- Scrubber Path: Delete operations are naturally idempotent


## Testing Strategy

### Unit Testing

**Cold Path Components**:
- `CrawlerLambda`: Mock GitHub API responses, verify S3 writes and DynamoDB updates
- Test pacing logic to ensure 4,500 req/hr rate
- Test bookmark read/write operations
- Test error handling for API failures

**Hot Path Components**:
- `EventsPoller`: Mock GitHub events API, verify Kinesis publishing
- `GraphUpdater`: Test event-to-Gremlin translation logic with idempotent patterns
- Mock Neptune connection, verify query generation
- Test that duplicate events result in idempotent operations (no duplicate edges)

**Scrubber Path Components**:
- `PingerLambda`: Mock GitHub repo API, test 404 handling
- Test OpenSearch and Neptune delete operations
- Verify SQS message processing

**Coverage Target**: 80% code coverage for all Lambda functions

### Integration Testing

**Cold Path Integration**:
- Deploy to test environment with small dataset (1,000 repos)
- Verify end-to-end flow: EventBridge → Lambda → S3 → DynamoDB
- Test Glue job transformation and bulk load to OpenSearch/Neptune
- Verify data consistency across all three query engines

**Hot Path Integration**:
- Simulate event stream with test data
- Verify Kinesis → Firehose → OpenSearch pipeline
- Verify Kinesis → GraphUpdater → Neptune pipeline
- Test real-time update latency (target: <5 seconds)

**Scrubber Path Integration**:
- Test with known deleted repositories
- Verify SQS → Lambda → OpenSearch/Neptune deletion flow
- Test DLQ handling for failed validations

### Load Testing

**Cold Path Load Test**:
- Simulate 48-day crawl with accelerated timeline
- Monitor Lambda execution times and memory usage
- Verify DynamoDB throughput is sufficient
- Test S3 write throughput at peak load

**Hot Path Load Test**:
- Simulate high event volume (10,000 events/minute)
- Test Kinesis shard auto-scaling
- Monitor OpenSearch indexing rate and latency
- Test Neptune write throughput for graph updates

**Query Engine Load Test**:
- Athena: Test query performance on full 500M repo dataset
- OpenSearch: Test concurrent search queries (100 req/sec)
- Neptune: Test complex graph traversals with large result sets

### End-to-End Testing

**Scenario 1: New Repository Creation**:
1. Cold Path ingests new repository from `/repositories`
2. Verify repository appears in S3, OpenSearch, and Neptune
3. Hot Path captures `WatchEvent` for the repository
4. Verify `stargazers_count` increments in OpenSearch
5. Verify `STARRED` edge created in Neptune

**Scenario 2: Repository Deletion**:
1. Repository is deleted on GitHub
2. Scrubber Path detects 404 response
3. Verify repository marked as deleted in OpenSearch
4. Verify repository vertex dropped from Neptune
5. Verify Athena queries exclude deleted repositories

**Scenario 3: Dashboard Real-Time Updates**:
1. Generate test events in Hot Path
2. Verify dashboard metrics update within 60 seconds
3. Test dashboard query performance under load
4. Verify CloudWatch metrics are accurate

### Performance Testing

**Metrics to Measure**:
- Cold Path: Repositories processed per hour (target: 10,500)
- Hot Path: Event processing latency (target: <5 seconds)
- OpenSearch: Query response time (target: <100ms for p95)
- Neptune: Graph traversal time (target: <500ms for 3-hop queries)
- Dashboard: Page load time (target: <2 seconds)

**Optimization Targets**:
- Lambda cold start time: <3 seconds
- Kinesis-to-OpenSearch latency: <60 seconds
- Kinesis-to-Neptune latency: <5 minutes
- Scrubber throughput: 100,000 repos/day


## Security Considerations

### Authentication and Authorization

**GitHub API Access**:
- Use GitHub Personal Access Token (PAT) with minimal required scopes
- Store token in AWS Secrets Manager, not environment variables
- Rotate token every 90 days
- Monitor token usage for anomalies

**AWS Service Access**:
- Use IAM roles for Lambda execution, not access keys
- Principle of least privilege for all IAM policies
- Separate roles for Cold Path, Hot Path, and Scrubber Path
- Enable CloudTrail for audit logging

**Dashboard Access**:
- Implement AWS Cognito for user authentication
- Use API Gateway authorizers for backend API
- Role-based access control (RBAC) for admin functions
- Enable MFA for admin users

### Data Security

**Data at Rest**:
- Enable S3 bucket encryption (SSE-S3 or SSE-KMS)
- Enable OpenSearch encryption at rest
- Enable Neptune encryption at rest
- Encrypt DynamoDB tables with AWS managed keys

**Data in Transit**:
- Use HTTPS for all GitHub API calls
- Use TLS for all AWS service communications
- Enable VPC endpoints for S3, DynamoDB, and Kinesis
- Use SSL/TLS for Neptune connections

**Network Security**:
- Deploy OpenSearch and Neptune in private subnets
- Use VPC security groups to restrict access
- Lambda functions in VPC for database access
- No public internet access to data stores

### Secrets Management

**GitHub Token Storage**:
```python
import boto3
from botocore.exceptions import ClientError

def get_github_token():
    secret_name = "github-api-token"
    region_name = "us-east-1"
    
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    
    try:
        response = client.get_secret_value(SecretId=secret_name)
        return response['SecretString']
    except ClientError as e:
        raise e
```

### Compliance and Privacy

**Data Retention**:
- S3 lifecycle policies for data archival
- Define retention periods for different data types
- Implement data deletion procedures for GDPR compliance

**Audit Logging**:
- Enable CloudTrail for all API calls
- Log all data access patterns
- Retain logs for minimum 1 year
- Implement log analysis for security monitoring

## Deployment Strategy

### Infrastructure as Code

**Tool**: Terraform (HCL)

**Rationale**: Terraform provides excellent AWS provider support, state management, and module reusability. It's cloud-agnostic (useful if we need multi-cloud in the future) and has strong community support.

**Project Structure**:
```
terraform/
├── modules/
│   ├── cold-path/          # EventBridge, Lambda, DynamoDB, S3
│   ├── hot-path/           # Kinesis, Lambda, Firehose
│   ├── scrubber-path/      # SQS, Glue Job, Lambda
│   ├── data-stores/        # OpenSearch, Neptune, Athena
│   ├── dashboard/          # API Gateway, Lambda, Amplify
│   └── monitoring/         # CloudWatch, SNS
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── main.tf
├── variables.tf
├── outputs.tf
└── backend.tf             # S3 backend for state management
```

**Terraform Modules**:
- `cold-path/`: EventBridge, Lambda, DynamoDB, S3
- `hot-path/`: Kinesis, Lambda, Firehose
- `scrubber-path/`: SQS, Glue Job, Lambda
- `data-stores/`: OpenSearch, Neptune, Athena
- `dashboard/`: API Gateway, Lambda, Amplify
- `monitoring/`: CloudWatch, SNS

### Deployment Phases

**Phase 1: Foundation (Week 1)**:
- Deploy S3 Data Lake and DynamoDB
- Deploy Cold Path pipeline
- Test with 10,000 repositories
- Validate S3 partitioning and compression

**Phase 2: Query Engines (Week 2)**:
- Deploy OpenSearch cluster
- Deploy Neptune cluster
- Implement Glue bulk load job
- Test data transformation and loading

**Phase 3: Real-Time Pipeline (Week 3)**:
- Deploy Kinesis stream and Firehose
- Deploy EventsPoller and GraphUpdater
- Test real-time updates to OpenSearch and Neptune
- Validate event deduplication

**Phase 4: Scrubber Pipeline (Week 4)**:
- Deploy SQS queue and PingerLambda
- Test deletion detection and cleanup
- Validate DLQ handling

**Phase 5: Dashboard (Week 5)**:
- Deploy backend API
- Deploy frontend application
- Integrate with CloudWatch metrics
- User acceptance testing

**Phase 6: Production Launch (Week 6)**:
- Enable Cold Path for full 48-day crawl
- Enable Hot Path for 24/7 monitoring
- Enable Scrubber Path weekly runs
- Monitor and optimize performance

### Rollback Strategy

**Lambda Rollback**:
- Use Lambda versioning and aliases
- Maintain previous version for quick rollback
- Automated rollback on error rate threshold

**Infrastructure Rollback**:
- Terraform state management
- Maintain previous infrastructure version
- Blue-green deployment for major changes

### Monitoring and Observability

**Key Metrics Dashboard**:
- Cold Path progress (% complete)
- Hot Path event rate (events/minute)
- Query engine health (latency, error rate)
- Cost metrics ($ per day by service)

**Alerting Rules**:
- Critical: Pipeline stalled >30 minutes
- High: Error rate >5%
- Medium: Cost exceeds budget threshold
- Low: Performance degradation detected

