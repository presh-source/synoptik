# Implementation Plan

- [x] 1. Set up project structure and foundational infrastructure
  - Create Terraform project structure with modules for each pipeline
  - Set up S3 backend for Terraform state management
  - Configure AWS provider and required IAM roles
  - Create GitHub token in AWS Secrets Manager
  - _Requirements: 14.1, 14.5_

- [x] 2. Implement Cold Path data ingestion pipeline
- [x] 2.1 Create S3 Data Lake infrastructure
  - Write Terraform module for S3 bucket with partitioning structure
  - Configure bucket encryption, lifecycle policies, and versioning
  - Set up Glue Data Catalog for Athena queries
  - _Requirements: 1.3, 10.1, 10.5_

- [x] 2.2 Create DynamoDB state management table
  - Write Terraform module for DynamoDB CrawlState table
  - Configure on-demand capacity and strong consistency
  - Create initial bookmark item with `last_processed_id = 0`
  - _Requirements: 2.2, 14.1_

- [x] 2.3 Implement CrawlerLambda function
  - Write Python Lambda function with GitHub API client
  - Implement bookmark read from DynamoDB at startup
  - Implement fixed loop of 1,050 requests with 0.8s pacing
  - Add S3 write logic with gzip compression and partitioning
  - Implement synchronous bookmark update at end of execution
  - _Requirements: 1.1, 1.2, 1.4, 1.5, 2.1, 2.3, 15.1_

- [x] 2.4 Create EventBridge orchestration
  - Write Terraform module for EventBridge cron rule (15 minutes)
  - Configure rule to trigger CrawlerLambda
  - Set up IAM permissions for EventBridge to invoke Lambda
  - _Requirements: 2.1, 2.5_

- [x] 2.5 Implement Cold Path error handling
  - Add retry logic for API failures with exponential backoff
  - Implement timeout monitoring (stop 30 seconds before Lambda timeout)
  - Add CloudWatch logging for all errors and state transitions
  - Configure SNS alerts for critical failures
  - _Requirements: 14.5, 15.2, 15.5_


- [ ] 3. Implement data transformation and bulk loading
- [ ] 3.1 Create AWS Glue transformation job
  - Write Glue PySpark script to read raw JSON from S3
  - Implement transformation logic to unified data model
  - Add data quality validation and error handling
  - _Requirements: 3.2, 3.3, 3.4_

- [ ] 3.2 Implement OpenSearch bulk loader
  - Write Python script to bulk load transformed data to OpenSearch
  - Create index mappings for repositories with proper field types
  - Implement batch processing with error handling
  - Configure index settings (shards, replicas)
  - _Requirements: 3.4, 11.1, 11.5_

- [ ] 3.3 Implement Neptune bulk loader
  - Write Gremlin script to create graph schema (vertices and edges)
  - Implement bulk load using Neptune bulk loader format
  - Create ownership relationships (User -[OWNS]-> Repository)
  - Add error handling and validation
  - _Requirements: 3.4, 7.1, 7.2, 7.5_

- [ ] 4. Set up query engine infrastructure
- [ ] 4.1 Deploy Amazon OpenSearch cluster
  - Write Terraform module for OpenSearch domain
  - Configure cluster with 3 data nodes (r6g.2xlarge) and dedicated masters
  - Enable encryption at rest and in transit
  - Set up VPC security groups and private subnet deployment
  - _Requirements: 11.1, 11.3, 11.5_

- [ ] 4.2 Deploy Amazon Neptune cluster
  - Write Terraform module for Neptune cluster
  - Configure 3 instances (db.r6g.2xlarge) with 2 read replicas
  - Enable encryption at rest and SSL/TLS for connections
  - Set up VPC security groups and private subnet deployment
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 4.3 Configure Athena for S3 queries
  - Create Glue Data Catalog database and tables
  - Define partitioning scheme for efficient queries
  - Set up Athena workgroup with query result location
  - _Requirements: 10.1, 10.2, 10.3_

- [ ] 5. Implement Hot Path real-time streaming pipeline
- [ ] 5.1 Create Kinesis Data Stream infrastructure
  - Write Terraform module for Kinesis stream with 10 shards
  - Configure 24-hour retention period
  - Set up CloudWatch metrics and alarms for stream health
  - _Requirements: 4.3, 14.3_

- [ ] 5.2 Implement EventsPoller Lambda
  - Write Python Lambda to poll GitHub /events API every minute
  - Implement Kinesis batch publishing with event ID as partition key
  - Add rate limit handling with exponential backoff
  - Configure EventBridge cron trigger (1 minute)
  - _Requirements: 4.1, 4.2, 4.5, 15.2_

- [ ] 5.3 Set up Kinesis Data Firehose to OpenSearch
  - Write Terraform module for Firehose delivery stream
  - Create transformation Lambda for event-to-document mapping
  - Configure buffer settings (5 MB, 60 seconds)
  - Set up S3 error bucket for failed records
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 5.4 Implement GraphUpdater Lambda for Neptune
  - Write Python Lambda to consume Kinesis stream (batch size: 100)
  - Implement event-to-Gremlin translation with idempotent coalesce() patterns
  - Add logic for WatchEvent, ForkEvent, PushEvent, IssuesEvent
  - Implement batch Gremlin query execution against Neptune
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 5.5 Implement Hot Path error handling
  - Add retry logic for Kinesis write failures
  - Implement DLQ for GraphUpdater Lambda failures
  - Add CloudWatch alarms for high error rates and Kinesis lag
  - Configure SNS notifications for critical issues
  - _Requirements: 14.3, 14.5_

- [ ] 6. Implement Scrubber Path deletion detection pipeline
- [ ] 6.1 Create SQS queue infrastructure
  - Write Terraform module for SQS standard queue
  - Configure visibility timeout (300 seconds) and retention (14 days)
  - Set up dead letter queue for failed validations
  - _Requirements: 9.1, 9.4, 14.4_

- [ ] 6.2 Implement Feeder Glue Job
  - Write Glue Python Shell script to query all repositories from S3/Athena
  - Implement batch SQS message sending (10 messages per batch)
  - Add throttling and error handling for long-running job
  - Configure EventBridge weekly trigger
  - _Requirements: 9.2, 9.5_

- [ ] 6.3 Implement PingerLambda for validation
  - Write Python Lambda to process SQS messages
  - Implement GitHub API check for repository existence
  - Add logic to handle 404 (deleted) and 403 (private) responses
  - Implement rate limiting for low-priority execution
  - _Requirements: 8.1, 8.2, 9.3, 9.4, 15.3_

- [ ] 6.4 Implement deletion cleanup logic
  - Add OpenSearch delete operation for marked repositories
  - Add Neptune Gremlin drop() operation for repository vertices
  - Implement idempotent delete operations
  - Add error handling and retry logic
  - _Requirements: 8.3, 8.4, 8.5_

- [ ] 7. Build observability dashboard backend API
- [x] 7.1 Create API Gateway and Lambda infrastructure
  - Write Terraform module for API Gateway REST API
  - Create Lambda functions for each API endpoint
  - Set up IAM roles and permissions for data access
  - Configure CORS and API throttling
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [x] 7.2 Implement pipeline status endpoints
  - Write Lambda to query DynamoDB for Cold Path bookmark
  - Implement calculation of ingestion rate and progress percentage
  - Add endpoint to query Kinesis metrics for Hot Path status
  - Add endpoint to query SQS queue depth for Scrubber Path
  - _Requirements: 12.1, 12.2, 12.5_

- [x] 7.3 Implement real-time metrics endpoints
  - Write Lambda to query OpenSearch for trending repositories
  - Implement aggregation queries for language and license distribution
  - Add time-series query for repository creation trends
  - Implement filtering by language, license, and date range
  - _Requirements: 13.1, 13.2, 13.3, 13.5_

- [x] 7.4 Implement CloudWatch metrics integration
  - Create Lambda to fetch CloudWatch metrics for all pipelines
  - Implement error rate and API request rate calculations
  - Add Lambda execution metrics and throttling detection
  - _Requirements: 12.4, 14.5_

- [x] 8. Build observability dashboard frontend
- [x] 8.1 Set up React application structure
  - Create React 18 + TypeScript project with Vite
  - Set up Material-UI (MUI) component library
  - Configure React Query for server state management
  - Set up routing with React Router
  - _Requirements: 13.4_

- [x] 8.2 Implement Pipeline Status Dashboard page
  - Create components to display Cold Path progress and rate
  - Add real-time Hot Path event processing metrics
  - Display Scrubber Path queue depth and validation rate
  - Add error rate indicators and alerts
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [x] 8.3 Implement Real-Time Metrics Dashboard page
  - Create trending repositories component with auto-refresh
  - Add language distribution chart using Recharts
  - Implement time-series chart for repository creation trends
  - Add filtering controls for language, license, and date range
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

- [x] 8.4 Deploy frontend to AWS
  - Write Terraform module for S3 bucket and CloudFront distribution
  - Configure CloudFront with SSL certificate
  - Set up CI/CD pipeline for automated deployments
  - _Requirements: 13.4_

- [ ] 9. Implement security and compliance features
- [ ] 9.1 Set up AWS Secrets Manager integration
  - Create secret for GitHub API token
  - Implement Lambda helper function to retrieve secrets
  - Configure automatic token rotation (90 days)
  - _Requirements: 15.1, 15.2, 15.3_

- [ ] 9.2 Configure encryption for all data stores
  - Enable S3 bucket encryption (SSE-S3)
  - Enable OpenSearch encryption at rest
  - Enable Neptune encryption at rest
  - Enable DynamoDB encryption with AWS managed keys
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 9.3 Implement VPC and network security
  - Create VPC with public and private subnets
  - Deploy OpenSearch and Neptune in private subnets
  - Configure security groups with least privilege access
  - Set up VPC endpoints for S3, DynamoDB, and Kinesis
  - _Requirements: 6.1, 11.1_

- [ ] 9.4 Set up CloudTrail and audit logging
  - Enable CloudTrail for all API calls
  - Configure log retention for 1 year minimum
  - Set up log analysis for security monitoring
  - _Requirements: 14.5_

- [ ] 10. Implement monitoring and alerting
- [ ] 10.1 Create CloudWatch dashboards
  - Build dashboard for Cold Path metrics (progress, rate, errors)
  - Build dashboard for Hot Path metrics (event rate, lag, errors)
  - Build dashboard for Scrubber Path metrics (queue depth, validation rate)
  - Add cost tracking dashboard by service
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [ ] 10.2 Configure CloudWatch alarms
  - Create alarm for Cold Path stalled (no progress in 30 minutes)
  - Create alarm for Hot Path high error rate (>5% failures)
  - Create alarm for Kinesis iterator age >1 hour
  - Create alarm for Lambda throttling detection
  - _Requirements: 14.5_

- [ ] 10.3 Set up SNS notification topics
  - Create SNS topic for critical alerts
  - Create SNS topic for warning alerts
  - Subscribe operations team email addresses
  - Configure alarm actions to publish to SNS
  - _Requirements: 14.5_

- [ ] 11. Deploy and test complete system
- [ ] 11.1 Deploy to development environment
  - Apply Terraform configuration for all modules
  - Verify all resources are created successfully
  - Test Cold Path with small dataset (1,000 repos)
  - Test Hot Path with simulated events
  - _Requirements: 1.1, 2.1, 4.1, 5.1, 8.1_

- [ ] 11.2 Perform integration testing
  - Test end-to-end Cold Path flow (API → S3 → Glue → OpenSearch/Neptune)
  - Test end-to-end Hot Path flow (API → Kinesis → OpenSearch/Neptune)
  - Test Scrubber Path deletion detection and cleanup
  - Verify data consistency across all three query engines
  - _Requirements: 3.4, 5.1, 8.2_

- [ ] 11.3 Deploy to production environment
  - Apply Terraform configuration for production
  - Enable Cold Path for full 48-day crawl
  - Enable Hot Path for 24/7 event monitoring
  - Enable Scrubber Path weekly runs
  - Monitor system health and performance
  - _Requirements: 2.5, 4.5, 9.5_
