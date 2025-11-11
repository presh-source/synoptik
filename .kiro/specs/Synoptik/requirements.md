# Requirements Document

## Introduction

This document specifies the requirements for a multi-modal, real-time digital twin platform of the entire public GitHub ecosystem. The system will ingest the complete historical baseline of 500M+ repositories and combine it with a 24/7 real-time stream of all public events. The platform will serve this unified dataset through three specialized query engines: Amazon S3 + Athena for cold analytics, Amazon OpenSearch for high-speed search and dashboards, and Amazon Neptune for graph-based relationship queries.

## Glossary

- **Cold Path**: The historical crawl pipeline that ingests all 500M+ repository metadata items from the GitHub API using the `/repositories` endpoint
- **Hot Path**: The real-time streaming pipeline that captures live GitHub events (PushEvent, WatchEvent, etc.) from the `/events` endpoint
- **Scrubber Path**: The background deletion detection pipeline that identifies and removes deleted or private repositories
- **CrawlerLambda**: AWS Lambda function that executes the serial crawl of repository metadata
- **EventsPoller**: AWS Lambda function that polls the GitHub `/events` API every minute
- **GraphUpdater**: AWS Lambda function that translates events into Gremlin queries for Neptune
- **PingerLambda**: AWS Lambda function that validates repository existence and handles deletions
- **Data Lake**: Amazon S3 storage containing raw, compressed JSON files from GitHub API responses
- **Digital Twin**: A complete, synchronized replica of the GitHub public ecosystem data
- **Kinesis Data Stream**: AWS service for real-time data streaming and fan-out to multiple consumers
- **Gremlin**: Graph traversal language used to query Amazon Neptune

## Requirements

### Requirement 1: Historical Data Ingestion

**User Story:** As a data analyst, I want to access the complete historical baseline of all GitHub repositories, so that I can perform comprehensive analytics on the entire ecosystem.

#### Acceptance Criteria

1. WHEN the Cold Path pipeline is initiated, THE CrawlerLambda SHALL retrieve repository metadata from the GitHub `/repositories` endpoint using the `since=ID` parameter
2. THE CrawlerLambda SHALL execute 1,050 API requests per 15-minute execution window to maintain a rate of 4,500 requests per hour
3. THE CrawlerLambda SHALL store raw compressed JSON files in the Data Lake with `.json.gz` format
4. THE CrawlerLambda SHALL maintain a bookmark of the last processed repository ID in a DynamoDB table named `CrawlState`
5. WHEN the CrawlerLambda completes an execution cycle, THE CrawlerLambda SHALL synchronously update the `last_processed_id` value in the DynamoDB bookmark

### Requirement 2: Cold Path Orchestration

**User Story:** As a system operator, I want the historical crawl to run continuously and reliably, so that the complete 500M+ repository baseline is ingested within 48 days.

#### Acceptance Criteria

1. THE Cold Path pipeline SHALL be triggered by an Amazon EventBridge cron rule set to `rate(15 minutes)`
2. WHEN the CrawlerLambda starts execution, THE CrawlerLambda SHALL read the `last_processed_id` from the DynamoDB `CrawlState` table once at startup
3. THE CrawlerLambda SHALL implement a pacing mechanism using sleep intervals of approximately 0.8 seconds between requests
4. THE CrawlerLambda SHALL have a maximum execution timeout of 15 minutes
5. WHEN all 500M+ repositories have been processed, THE Cold Path pipeline SHALL complete the historical baseline ingestion

### Requirement 3: Data Model Storage

**User Story:** As a data engineer, I want repository data stored in a unified model across all query engines, so that I can perform consistent queries regardless of the engine used.

#### Acceptance Criteria

1. THE Data Lake SHALL store the complete raw JSON response from GitHub API endpoints in S3
2. THE Repository entity SHALL contain the following fields: `id`, `full_name`, `description`, `language`, `license.name`, `stargazers_count`, `forks_count`, `watchers_count`, `open_issues_count`, `created_at`, `pushed_at`, and `is_deleted`
3. THE system SHALL transform raw S3 data into the unified data model for loading into OpenSearch and Neptune
4. WHEN the Cold Path completes, THE system SHALL execute an AWS Glue job to bulk-load transformed data into OpenSearch and Neptune
5. THE unified data model SHALL use `id` as the primary key for Repository entities

### Requirement 4: Real-Time Event Ingestion

**User Story:** As a real-time analytics user, I want to see live GitHub activity as it happens, so that I can monitor trending repositories and user behavior in real-time.

#### Acceptance Criteria

1. THE EventsPoller SHALL poll the GitHub `/events` API endpoint every 60 seconds
2. WHEN the EventsPoller retrieves events, THE EventsPoller SHALL publish raw event data to a Kinesis Data Stream
3. THE Kinesis Data Stream SHALL support multiple concurrent consumers for fan-out processing
4. THE Hot Path pipeline SHALL process the following event types: `PushEvent`, `WatchEvent`, `ForkEvent`, and `IssuesEvent`
5. THE Hot Path pipeline SHALL operate continuously with 24/7 availability

### Requirement 5: OpenSearch Real-Time Updates

**User Story:** As a dashboard user, I want repository metrics to update in real-time, so that I can see current stargazer counts and activity levels.

#### Acceptance Criteria

1. THE Kinesis Data Firehose SHALL consume events from the Kinesis Data Stream and deliver them to OpenSearch
2. WHEN a `WatchEvent` is received, THE OpenSearch cluster SHALL increment the `stargazers_count` field for the corresponding repository
3. WHEN a `ForkEvent` is received, THE OpenSearch cluster SHALL increment the `forks_count` field for the corresponding repository
4. WHEN a `PushEvent` is received, THE OpenSearch cluster SHALL update the `pushed_at` timestamp for the corresponding repository
5. WHEN an `IssuesEvent` is received, THE OpenSearch cluster SHALL update the `open_issues_count` field for the corresponding repository

### Requirement 6: Graph Relationship Management

**User Story:** As a researcher, I want to query complex relationships between users, repositories, and issues, so that I can analyze collaboration patterns and network effects.

#### Acceptance Criteria

1. THE GraphUpdater SHALL consume events from the Kinesis Data Stream and translate them into Gremlin queries
2. WHEN a `WatchEvent` is processed, THE GraphUpdater SHALL create a `(User) -[STARRED]-> (Repo)` edge in Neptune
3. WHEN a `ForkEvent` is processed, THE GraphUpdater SHALL create a `(User) -[FORKED]-> (Repo)` edge in Neptune
4. WHEN a `PushEvent` is processed, THE GraphUpdater SHALL create a `(User) -[COMMITTED_TO]-> (Repo)` edge in Neptune
5. WHEN an `IssuesEvent` is processed, THE GraphUpdater SHALL create `(User) -[OPENED]-> (Issue)` and `(Issue) -[BELONGS_TO]-> (Repo)` edges in Neptune

### Requirement 7: Repository Ownership Relationships

**User Story:** As a graph analyst, I want to query repository ownership relationships, so that I can identify prolific contributors and organizational structures.

#### Acceptance Criteria

1. WHEN the Cold Path processes repository metadata, THE system SHALL extract owner information from the raw JSON
2. THE system SHALL create a `(User) -[OWNS]-> (Repo)` edge in Neptune for each repository-owner pair
3. THE Neptune graph SHALL support traversal queries to find all repositories owned by a specific user
4. THE Neptune graph SHALL support traversal queries to find the owner of a specific repository
5. THE ownership relationship SHALL be established during the initial bulk-load from the Cold Path data

### Requirement 8: Deletion Detection and Cleanup

**User Story:** As a data quality manager, I want deleted or private repositories removed from the system, so that query results remain accurate and up-to-date.

#### Acceptance Criteria

1. THE Scrubber Path SHALL validate repository existence using the GitHub `/repos/{owner}/{repo}` endpoint
2. WHEN the PingerLambda receives an HTTP 404 response, THE PingerLambda SHALL set the `is_deleted` flag to true for the repository
3. WHEN a repository is marked as deleted, THE system SHALL execute a delete command in OpenSearch to remove the repository document
4. WHEN a repository is marked as deleted, THE system SHALL execute a Gremlin `drop()` command in Neptune to remove the repository vertex and all connected edges
5. THE Scrubber Path SHALL process all 500M+ repositories at a low priority to avoid impacting the Cold Path and Hot Path pipelines

### Requirement 9: Scrubber Path Orchestration

**User Story:** As a system operator, I want the deletion detection process to run continuously in the background, so that stale data is eventually removed without impacting primary pipelines.

#### Acceptance Criteria

1. THE Scrubber Path SHALL use an SQS Queue to manage the list of repositories to validate
2. WHEN a weekly Lambda feeder process executes, THE feeder SHALL query Athena for all repository names and populate the SQS Queue
3. THE PingerLambda SHALL be triggered by SQS messages to process repository validation requests
4. THE PingerLambda SHALL implement rate limiting to ensure low-priority execution
5. THE Scrubber Path SHALL operate independently from the Cold Path and Hot Path pipelines

### Requirement 10: Cold Analytics Query Engine

**User Story:** As a data scientist, I want to run SQL queries on the complete raw archive, so that I can perform custom analytics without incurring high compute costs.

#### Acceptance Criteria

1. THE Data Lake SHALL organize raw JSON files in S3 with a partitioning scheme that supports efficient Athena queries
2. THE system SHALL provide an AWS Glue Data Catalog that defines the schema for repository data in S3
3. THE Athena query engine SHALL support SQL queries against the complete historical baseline stored in S3
4. THE Athena query engine SHALL provide query results within acceptable latency for cold analytics use cases
5. THE S3 storage SHALL use compression to minimize storage costs for the 500M+ repository dataset

### Requirement 11: High-Speed Search Engine

**User Story:** As an application developer, I want to perform fast text searches and aggregations on repository data, so that I can build responsive user interfaces and dashboards.

#### Acceptance Criteria

1. THE OpenSearch cluster SHALL index all repository entities with full-text search capabilities on the `description` and `full_name` fields
2. THE OpenSearch cluster SHALL support aggregation queries for metrics such as total repositories by language and license distribution
3. THE OpenSearch cluster SHALL provide query response times under 100 milliseconds for typical search queries
4. THE OpenSearch cluster SHALL support real-time updates from the Hot Path pipeline with minimal latency
5. THE OpenSearch cluster SHALL scale to handle the complete 500M+ repository dataset

### Requirement 12: Observability Dashboard

**User Story:** As a system operator, I want to monitor the health and progress of all three pipelines, so that I can identify and resolve issues quickly.

#### Acceptance Criteria

1. THE observability dashboard SHALL display the current `last_processed_id` value from the Cold Path pipeline
2. THE observability dashboard SHALL display the ingestion rate in repositories per hour for the Cold Path pipeline
3. THE observability dashboard SHALL display the event processing rate in events per minute for the Hot Path pipeline
4. THE observability dashboard SHALL display error rates and failed API requests for all three pipelines
5. THE observability dashboard SHALL display the current size of the SQS Queue for the Scrubber Path pipeline

### Requirement 13: Dashboard Real-Time Metrics

**User Story:** As a business stakeholder, I want to see real-time metrics on GitHub ecosystem activity, so that I can understand trends and make data-driven decisions.

#### Acceptance Criteria

1. THE observability dashboard SHALL query OpenSearch to display the top 10 most-starred repositories in the last 24 hours
2. THE observability dashboard SHALL display the total count of repositories by programming language
3. THE observability dashboard SHALL display a time-series chart of repository creation events over the last 30 days
4. THE observability dashboard SHALL refresh metrics automatically every 60 seconds
5. THE observability dashboard SHALL provide filtering capabilities by language, license, and date range

### Requirement 14: Pipeline State Management

**User Story:** As a DevOps engineer, I want pipeline state to be durable and recoverable, so that the system can resume operations after failures without data loss.

#### Acceptance Criteria

1. THE DynamoDB `CrawlState` table SHALL persist the `last_processed_id` with strong consistency guarantees
2. WHEN the CrawlerLambda fails mid-execution, THE next execution SHALL resume from the last successfully committed `last_processed_id`
3. THE Kinesis Data Stream SHALL retain events for 24 hours to allow consumer recovery from failures
4. THE SQS Queue SHALL implement dead-letter queue handling for repositories that fail validation after multiple retry attempts
5. THE system SHALL log all state transitions and errors to Amazon CloudWatch for debugging and audit purposes

### Requirement 15: API Rate Limit Compliance

**User Story:** As a system architect, I want all pipelines to respect GitHub API rate limits, so that the system operates reliably without being throttled or banned.

#### Acceptance Criteria

1. THE CrawlerLambda SHALL maintain a request rate of 4,500 requests per hour to stay within GitHub API limits
2. THE EventsPoller SHALL implement exponential backoff when receiving HTTP 429 rate limit responses
3. THE PingerLambda SHALL implement rate limiting to ensure the Scrubber Path operates at low priority
4. THE system SHALL monitor API rate limit headers and adjust request rates dynamically if approaching limits
5. THE system SHALL log all rate limit violations to CloudWatch for monitoring and alerting
