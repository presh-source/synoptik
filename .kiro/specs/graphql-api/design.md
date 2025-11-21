# Design Document

## Overview

This design implements a GraphQL API using AWS AppSync for the Synoptik observability platform. The solution provides real-time subscriptions for crawler completion events, flexible querying of pipeline metrics, and a custom domain for a branded API experience. AppSync integrates with existing Lambda functions as data sources, ensuring consistency with the REST API while adding real-time capabilities.

The system follows a managed service architecture:
1. **AppSync Layer**: Managed GraphQL API with schema, resolvers, and subscriptions
2. **Data Source Layer**: Lambda functions that fetch data from CloudWatch and DynamoDB
3. **Event Publishing Layer**: Crawlers publish completion events to AppSync
4. **Client Layer**: React frontend with Apollo Client for queries and subscriptions

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Frontend (React + Apollo Client)                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Apollo Client Configuration:                                 │  │
│  │  - ApolloLink (HTTP) for Queries/Mutations                    │  │
│  │  - WebSocketLink for Subscriptions                            │  │
│  │  - InMemoryCache with type policies                           │  │
│  │  - Auto-reconnect on connection loss                          │  │
│  └───────────────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────┬───────────────────┘
                 │                                │
                 │ HTTPS                          │ WSS (wss://)
                 │ (API Key Auth)                 │ (API Key Auth)
                 ▼                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Custom Domain: graphql.synoptik.io                      │
│  - Route 53 A Record → AppSync Domain Name                          │
│  - ACM Certificate (*.synoptik.io)                                   │
│  - CloudFront Distribution (managed by AppSync)                      │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS AppSync API                              │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  GraphQL Schema (schema.graphql)                              │  │
│  │  ├─ Query                                                      │  │
│  │  │  ├─ pipelineStatus: PipelineStatus                         │  │
│  │  │  ├─ repoCrawler(timePeriodHours: Int): CrawlerMetrics      │  │
│  │  │  ├─ userCrawler(timePeriodHours: Int): CrawlerMetrics      │  │
│  │  │  └─ errorRates: ErrorRates                                 │  │
│  │  ├─ Mutation                                                   │  │
│  │  │  └─ publishCrawlerCompleted(input: ...): CrawlerCompleted  │  │
│  │  └─ Subscription                                               │  │
│  │     └─ onCrawlerCompleted(crawlerType: String): CrawlerComp.. │  │
│  │                                                                │  │
│  │  Authorization:                                                │  │
│  │  - API_KEY (default) for frontend queries/subscriptions       │  │
│  │  - AWS_IAM for crawler mutations                              │  │
│  │                                                                │  │
│  │  Caching: Server-side caching (TTL: 30 seconds)               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Data Sources:                                                       │
│  ├─ Lambda: pipeline_status_resolver                                │
│  ├─ Lambda: crawler_metrics_resolver                                │
│  ├─ Lambda: error_rates_resolver                                    │
│  └─ NONE: publishCrawlerCompleted (local resolver)                  │
└────────────────┬────────────────────────────────┬───────────────────┘
                 │                                │
                 │ Invoke Lambda                  │ HTTP POST
                 │ (IAM Auth)                     │ (IAM Auth)
                 ▼                                ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│  Lambda Data Sources         │    │  Crawler Lambdas             │
│  - pipeline_status.py        │    │  - repo_crawler.py           │
│  - (reuse existing functions)│    │  - user_crawler.py           │
│                              │    │  - appsync_client.py         │
└──────────────┬───────────────┘    └──────────────────────────────┘
               │
               ├──────────────────┬──────────────────┐
               ▼                  ▼                  ▼
       ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
       │  DynamoDB    │  │  CloudWatch  │  │  CloudWatch  │
       │  (Bookmarks) │  │  (Metrics)   │  │  (Errors)    │
       └──────────────┘  └──────────────┘  └──────────────┘
```

### Data Flow

#### Query Flow
1. Frontend sends GraphQL query to AppSync via HTTPS
2. AppSync validates query against schema
3. AppSync invokes Lambda data source with resolver mapping
4. Lambda fetches data from CloudWatch/DynamoDB
5. Lambda returns data to AppSync
6. AppSync maps response and returns to client
7. Apollo Client caches result

#### Subscription Flow
1. Frontend establishes WebSocket connection to AppSync
2. Client sends subscription request
3. AppSync registers subscription and keeps connection open
4. When mutation is called, AppSync evaluates subscription filters
5. AppSync pushes data to all matching subscriptions via WebSocket
6. Apollo Client updates cache and triggers React re-render

#### Event Publishing Flow
1. Crawler Lambda completes execution
2. Crawler calls AppSync HTTP endpoint with mutation
3. AppSync authenticates using IAM credentials
4. AppSync executes mutation (NONE data source)
5. AppSync triggers all active subscriptions
6. Connected clients receive event in real-time

## Components and Interfaces

### GraphQL Schema


```graphql
# schema.graphql

type Query {
  """Get complete pipeline status including all crawlers and error rates"""
  pipelineStatus: PipelineStatus!
  
  """Get repository crawler metrics for a specific time period"""
  repoCrawler(timePeriodHours: Int = 1): CrawlerMetrics!
  
  """Get user crawler metrics for a specific time period"""
  userCrawler(timePeriodHours: Int = 1): CrawlerMetrics!
  
  """Get error rates for the cold path pipeline"""
  errorRates: ErrorRates!
}

type Mutation {
  """Publish crawler completion event (called by crawler Lambdas)"""
  publishCrawlerCompleted(input: CrawlerCompletedInput!): CrawlerCompleted!
}

type Subscription {
  """Subscribe to crawler completion events, optionally filtered by crawler type"""
  onCrawlerCompleted(crawlerType: String): CrawlerCompleted
    @aws_subscribe(mutations: ["publishCrawlerCompleted"])
}

# Types

type PipelineStatus {
  coldPath: ColdPathStatus!
  errorRates: ErrorRates!
}

type ColdPathStatus {
  lastProcessedId: Int!
  totalProcessed: Int!
  updatedAt: AWSDateTime!
  repoCrawler: CrawlerMetrics!
  userCrawler: CrawlerMetrics!
}

type CrawlerMetrics {
  lastProcessedId: Int!
  totalProcessed: Int!
  totalCrawled: Int!
  ratePerHour: Float!
  ratePerMinute: Float!
  ratePerSecond: Float!
  requestCount: Int!
  runCount: Int!
}

type ErrorRates {
  coldPath: Float!
}

type CrawlerCompleted {
  crawlerType: String!
  startId: Int!
  endId: Int!
  itemsFetched: Int!
  totalProcessed: Int!
  completedAt: AWSDateTime!
  success: Boolean!
  errorMessage: String
}

# Inputs

input CrawlerCompletedInput {
  crawlerType: String!
  startId: Int!
  endId: Int!
  itemsFetched: Int!
  totalProcessed: Int!
  success: Boolean!
  errorMessage: String
}
```

### AppSync Resolver Configurations

#### Query.pipelineStatus Resolver

**Data Source**: Lambda (pipeline_status_resolver)

**Request Mapping Template (VTL)**:
```vtl
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "pipelineStatus",
    "arguments": $util.toJson($context.arguments)
  }
}
```

**Response Mapping Template (VTL)**:
```vtl
$util.toJson($context.result)
```

#### Query.repoCrawler Resolver

**Data Source**: Lambda (crawler_metrics_resolver)

**Request Mapping Template**:
```vtl
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "repoCrawler",
    "crawlerType": "repo",
    "timePeriodHours": $util.defaultIfNull($context.arguments.timePeriodHours, 1)
  }
}
```

#### Mutation.publishCrawlerCompleted Resolver

**Data Source**: NONE (local resolver)

**Request Mapping Template**:
```vtl
{
  "version": "2018-05-29",
  "payload": {
    "crawlerType": "$context.arguments.input.crawlerType",
    "startId": $context.arguments.input.startId,
    "endId": $context.arguments.input.endId,
    "itemsFetched": $context.arguments.input.itemsFetched,
    "totalProcessed": $context.arguments.input.totalProcessed,
    "completedAt": "$util.time.nowISO8601()",
    "success": $context.arguments.input.success,
    "errorMessage": "$util.defaultIfNull($context.arguments.input.errorMessage, null)"
  }
}
```

**Response Mapping Template**:
```vtl
$util.toJson($context.result)
```

### Lambda Data Source Functions

#### pipeline_status_resolver.py

```python
"""
AppSync resolver Lambda for pipeline status queries
Reuses existing business logic from pipeline_status.py
"""

import json
from pipeline_status import get_pipeline_status

def lambda_handler(event, context):
    """
    Handle AppSync resolver requests
    
    Event structure from AppSync:
    {
        "field": "pipelineStatus",
        "arguments": {}
    }
    """
    field = event.get('field')
    
    if field == 'pipelineStatus':
        # Reuse existing function
        result = get_pipeline_status()
        return result
    
    return {"error": f"Unknown field: {field}"}
```

#### crawler_metrics_resolver.py

```python
"""
AppSync resolver Lambda for crawler metrics queries
"""

import json
from pipeline_status import get_crawler_metrics_from_cloudwatch, get_cold_path_status

def lambda_handler(event, context):
    """
    Handle crawler metrics queries
    
    Event structure:
    {
        "field": "repoCrawler" | "userCrawler",
        "crawlerType": "repo" | "user",
        "timePeriodHours": 1
    }
    """
    crawler_type = event.get('crawlerType')
    time_period = event.get('timePeriodHours', 1)
    
    # Get metrics from CloudWatch
    metrics = get_crawler_metrics_from_cloudwatch(crawler_type, time_period)
    
    # Get bookmark data from DynamoDB
    cold_path_status = get_cold_path_status()
    
    # Enrich metrics with bookmark data
    metrics['lastProcessedId'] = cold_path_status['lastProcessedId']
    metrics['totalProcessed'] = cold_path_status['totalProcessed']
    
    return metrics
```


### Crawler Integration - AppSync Event Publishing

#### appsync_client.py

```python
"""
AppSync HTTP client for publishing events from crawlers
Uses AWS Signature Version 4 for IAM authentication
"""

import json
import os
from datetime import datetime, timezone
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests

APPSYNC_ENDPOINT = os.environ.get('appsync_api_url')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

def publish_crawler_completed(
    crawler_type: str,
    start_id: int,
    end_id: int,
    items_fetched: int,
    total_processed: int,
    success: bool = True,
    error_message: str = None
):
    """
    Publish crawler completion event to AppSync
    
    Args:
        crawler_type: "repo" or "user"
        start_id: Starting ID for this crawl
        end_id: Ending ID for this crawl
        items_fetched: Number of items fetched in this run
        total_processed: Total items processed across all runs
        success: Whether the crawl succeeded
        error_message: Error message if failed
    """
    
    mutation = """
    mutation PublishCrawlerCompleted($input: CrawlerCompletedInput!) {
      publishCrawlerCompleted(input: $input) {
        crawlerType
        completedAt
      }
    }
    """
    
    variables = {
        "input": {
            "crawlerType": crawler_type,
            "startId": start_id,
            "endId": end_id,
            "itemsFetched": items_fetched,
            "totalProcessed": total_processed,
            "success": success,
            "errorMessage": error_message
        }
    }
    
    payload = {
        "query": mutation,
        "variables": variables
    }
    
    # Sign request with IAM credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    request = AWSRequest(
        method='POST',
        url=APPSYNC_ENDPOINT,
        data=json.dumps(payload),
        headers={
            'Content-Type': 'application/json'
        }
    )
    
    SigV4Auth(credentials, 'appsync', AWS_REGION).add_auth(request)
    
    # Send request
    response = requests.post(
        APPSYNC_ENDPOINT,
        headers=dict(request.headers),
        data=request.body
    )
    
    if response.status_code != 200:
        raise Exception(f"AppSync request failed: {response.status_code} {response.text}")
    
    return response.json()
```

#### Updated repo_crawler.py (additions)

```python
# Add at top of file
from appsync_client import publish_crawler_completed

# In lambda_handler, after successful crawl:
if last_id > start_id:
    # ... existing bookmark update code ...
    
    # Publish completion event to AppSync
    try:
        publish_crawler_completed(
            crawler_type="repo",
            start_id=start_id,
            end_id=last_id,
            items_fetched=total_fetched,
            total_processed=new_total,
            success=True
        )
        logger.info("Published crawler completion event to AppSync")
    except Exception as e:
        logger.error(f"Failed to publish to AppSync: {e}")
        # Don't fail the crawler if AppSync publish fails
```

### Frontend - Apollo Client Configuration

#### graphql/client.ts

```typescript
import { ApolloClient, InMemoryCache, HttpLink, split } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { getMainDefinition } from '@apollo/client/utilities';
import { createClient } from 'graphql-ws';

const APPSYNC_ENDPOINT = import.meta.env.VITE_appsync_api_url;
const APPSYNC_API_KEY = import.meta.env.VITE_APPSYNC_API_KEY;
const APPSYNC_REALTIME_ENDPOINT = import.meta.env.VITE_APPSYNC_REALTIME_ENDPOINT;

// HTTP link for queries and mutations
const httpLink = new HttpLink({
  uri: APPSYNC_ENDPOINT,
  headers: {
    'x-api-key': APPSYNC_API_KEY,
  },
});

// WebSocket link for subscriptions
const wsLink = new GraphQLWsLink(
  createClient({
    url: APPSYNC_REALTIME_ENDPOINT,
    connectionParams: {
      'x-api-key': APPSYNC_API_KEY,
    },
    retryAttempts: 5,
    shouldRetry: () => true,
  })
);

// Split based on operation type
const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query);
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    );
  },
  wsLink,
  httpLink
);

// Create Apollo Client
export const apolloClient = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          pipelineStatus: {
            merge: true,
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
  },
});
```

#### graphql/queries.ts

```typescript
import { gql } from '@apollo/client';

export const GET_PIPELINE_STATUS = gql`
  query GetPipelineStatus {
    pipelineStatus {
      coldPath {
        lastProcessedId
        totalProcessed
        updatedAt
        repoCrawler {
          totalCrawled
          ratePerHour
          ratePerMinute
          ratePerSecond
          requestCount
          runCount
        }
        userCrawler {
          totalCrawled
          ratePerHour
          ratePerMinute
          ratePerSecond
          requestCount
          runCount
        }
      }
      errorRates {
        coldPath
      }
    }
  }
`;

export const GET_REPO_CRAWLER_METRICS = gql`
  query GetRepoCrawlerMetrics($timePeriodHours: Int) {
    repoCrawler(timePeriodHours: $timePeriodHours) {
      totalCrawled
      ratePerHour
      ratePerMinute
      requestCount
      runCount
    }
  }
`;
```

#### graphql/subscriptions.ts

```typescript
import { gql } from '@apollo/client';

export const ON_CRAWLER_COMPLETED = gql`
  subscription OnCrawlerCompleted($crawlerType: String) {
    onCrawlerCompleted(crawlerType: $crawlerType) {
      crawlerType
      startId
      endId
      itemsFetched
      totalProcessed
      completedAt
      success
      errorMessage
    }
  }
`;
```

#### Example React Component with Subscription

```typescript
import { useSubscription, useQuery } from '@apollo/client';
import { ON_CRAWLER_COMPLETED } from '../graphql/subscriptions';
import { GET_PIPELINE_STATUS } from '../graphql/queries';

export function CrawlerDashboard() {
  // Query for initial data
  const { data, loading, refetch } = useQuery(GET_PIPELINE_STATUS, {
    pollInterval: 30000, // Fallback polling
  });

  // Subscribe to real-time updates
  const { data: subscriptionData } = useSubscription(ON_CRAWLER_COMPLETED, {
    onData: ({ data }) => {
      console.log('Crawler completed:', data.data?.onCrawlerCompleted);
      // Refetch pipeline status when crawler completes
      refetch();
    },
  });

  if (loading) return <LoadingSkeleton />;

  return (
    <div>
      <h1>Pipeline Status</h1>
      {subscriptionData?.onCrawlerCompleted && (
        <Alert severity="success">
          {subscriptionData.onCrawlerCompleted.crawlerType} crawler completed!
          Fetched {subscriptionData.onCrawlerCompleted.itemsFetched} items.
        </Alert>
      )}
      {/* Render metrics */}
    </div>
  );
}
```

## Data Models

### TypeScript Types (Auto-generated)

```typescript
// Generated by GraphQL Code Generator

export type Maybe<T> = T | null;

export type CrawlerMetrics = {
  __typename?: 'CrawlerMetrics';
  lastProcessedId: number;
  totalProcessed: number;
  totalCrawled: number;
  ratePerHour: number;
  ratePerMinute: number;
  ratePerSecond: number;
  requestCount: number;
  runCount: number;
};

export type CrawlerCompleted = {
  __typename?: 'CrawlerCompleted';
  crawlerType: string;
  startId: number;
  endId: number;
  itemsFetched: number;
  totalProcessed: number;
  completedAt: string;
  success: boolean;
  errorMessage?: Maybe<string>;
};

export type PipelineStatus = {
  __typename?: 'PipelineStatus';
  coldPath: ColdPathStatus;
  errorRates: ErrorRates;
};

// ... more types
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: GraphQL schema validation
*For any* GraphQL query sent to AppSync, if the query is syntactically valid and matches the schema, then AppSync should execute the query and return data or errors.
**Validates: Requirements 1.1, 1.3**

### Property 2: Selective field fetching
*For any* GraphQL query that requests specific fields, the response should contain only the requested fields and omit unrequested fields.
**Validates: Requirements 1.2**

### Property 3: Type enforcement
*For any* field in the GraphQL schema with a defined type, AppSync should enforce that type at runtime and return an error if the resolver returns incompatible data.
**Validates: Requirements 2.3**

### Property 4: Crawler type filtering
*For any* query for `repoCrawler`, the system should return only repository crawler metrics, and for `userCrawler`, only user crawler metrics.
**Validates: Requirements 3.1, 3.2**

### Property 5: Independent error rate queries
*For any* query that requests only `errorRates`, the system should return error rate data without requiring or fetching other pipeline metrics.
**Validates: Requirements 4.1**

### Property 6: Subscription establishment
*For any* subscription request to `onCrawlerCompleted`, Apollo Client should establish a WebSocket connection to AppSync and keep it open.
**Validates: Requirements 5.2, 13.2**

### Property 7: Event delivery to subscribers
*For any* `publishCrawlerCompleted` mutation, all clients subscribed to `onCrawlerCompleted` should receive the event via WebSocket.
**Validates: Requirements 13.3, 14.3, 15.3**

### Property 8: Subscription filtering
*For any* subscription with a `crawlerType` filter, only events matching that crawler type should be delivered to the subscriber.
**Validates: Requirements 13.4**

### Property 9: Resolver reuse
*For any* GraphQL query that fetches crawler metrics, the AppSync resolver should invoke the same Lambda functions used by the REST API.
**Validates: Requirements 7.1, 7.2, 7.3**

### Property 10: Error propagation
*For any* resolver that throws an exception, AppSync should return a GraphQL error with a message in the errors array.
**Validates: Requirements 8.1**

### Property 11: Partial data on failure
*For any* query where some fields fail but others succeed, AppSync should return the successful fields with errors for the failed fields.
**Validates: Requirements 8.2**

### Property 12: Custom domain resolution
*For any* request to the custom domain (graphql.synoptik.io), Route 53 should resolve to the AppSync API endpoint.
**Validates: Requirements 9.2, 9.3**

### Property 13: IAM authentication for mutations
*For any* `publishCrawlerCompleted` mutation from a crawler Lambda, AppSync should validate IAM credentials before executing.
**Validates: Requirements 17.2**

### Property 14: API key authentication for queries
*For any* query or subscription from the frontend, AppSync should validate the API key before executing.
**Validates: Requirements 17.3**

### Property 15: TypeScript type generation
*For any* field in the GraphQL schema, the code generator should produce corresponding TypeScript types.
**Validates: Requirements 10.1, 10.2**

### Property 16: Subscription reconnection
*For any* WebSocket connection that drops, Apollo Client should automatically attempt to reconnect and resume subscriptions.
**Validates: Requirements 13.5, 18.4**

### Property 17: Cache invalidation on subscription
*For any* subscription event received, Apollo Client should update the cache and trigger React component re-renders.
**Validates: Requirements 18.3**

### Property 18: Event publishing on crawler completion
*For any* successful crawler execution, the crawler should publish a `publishCrawlerCompleted` mutation to AppSync.
**Validates: Requirements 14.1, 15.1**

## Error Handling

### AppSync Error Handling

**Schema Validation Errors**:
- AppSync validates all queries against the schema before execution
- Returns detailed error messages with field paths
- HTTP 400 for validation errors

**Resolver Errors**:
- Lambda errors are caught and returned in the `errors` array
- Partial data is returned if some fields succeed
- Error messages include field path and error type

**Authorization Errors**:
- IAM authentication failures return 401 Unauthorized
- API key validation failures return 403 Forbidden
- Detailed error messages in CloudWatch Logs

**Subscription Errors**:
- WebSocket connection failures trigger automatic reconnection
- Subscription errors are logged to CloudWatch
- Clients receive error events via WebSocket

### Lambda Data Source Error Handling

**CloudWatch Query Failures**:
- Return zero values for metrics
- Log error to CloudWatch and Sentry
- Continue with other fields

**DynamoDB Query Failures**:
- Return default values (0 for IDs, current timestamp)
- Log error to CloudWatch and Sentry
- Don't fail the entire query

**Timeout Handling**:
- Lambda timeout set to 30 seconds
- AppSync timeout set to 30 seconds
- Return partial data if timeout occurs

### Crawler Event Publishing Error Handling

**AppSync HTTP Request Failures**:
- Log error but don't fail the crawler
- Crawler success is independent of event publishing
- Retry logic with exponential backoff (3 attempts)

**IAM Authentication Failures**:
- Log error with full context
- Alert via CloudWatch alarm
- Don't retry (indicates configuration issue)

## Testing Strategy

### Unit Testing

**Backend (Python)**:
- Test AppSync resolver Lambda functions with mocked AppSync events
- Test `appsync_client.py` with mocked HTTP responses
- Test IAM signature generation
- Test error handling for all failure scenarios

**Frontend (TypeScript/React)**:
- Test Apollo Client configuration
- Test subscription setup and teardown
- Test cache updates on subscription events
- Test WebSocket reconnection logic
- Test component rendering with subscription data

### Integration Testing

**AppSync Integration**:
- Deploy to test environment
- Execute queries and verify responses
- Publish mutations and verify subscription delivery
- Test custom domain resolution
- Test IAM and API key authentication

**End-to-End Flow**:
1. Trigger crawler Lambda manually
2. Verify crawler publishes event to AppSync
3. Verify frontend receives subscription event
4. Verify UI updates with new data

### Subscription Testing

**WebSocket Connection**:
- Test connection establishment
- Test automatic reconnection on disconnect
- Test subscription filtering
- Test multiple concurrent subscriptions

**Event Delivery**:
- Publish test events via mutation
- Verify all subscribers receive events
- Verify filtered subscriptions receive only matching events
- Test event delivery latency (< 1 second)

### Performance Testing

**Query Performance**:
- Measure query response time (target: < 3 seconds)
- Test with AppSync caching enabled
- Test concurrent queries

**Subscription Performance**:
- Test with 100+ concurrent subscriptions
- Measure event delivery latency
- Test WebSocket connection limits

## Security Considerations

### Authorization

**Multi-Auth Configuration**:
- Default: API_KEY for frontend (queries, subscriptions)
- Additional: AWS_IAM for crawlers (mutations)
- API keys rotated every 90 days
- IAM roles follow least privilege

**API Key Management**:
- Stored in AWS Secrets Manager
- Injected into frontend at build time
- Not committed to version control
- Separate keys for dev/staging/prod

**IAM Policies**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "appsync:GraphQL",
      "Resource": "arn:aws:appsync:region:account:apis/api-id/*"
    }
  ]
}
```

### Data Security

**Encryption**:
- HTTPS for all HTTP requests
- WSS (WebSocket Secure) for subscriptions
- Data encrypted in transit (TLS 1.2+)
- No sensitive data in GraphQL responses

**CORS Configuration**:
- Allow only frontend domain
- Restrict HTTP methods to POST
- Include credentials in requests

### Network Security

**Custom Domain**:
- ACM certificate for TLS
- CloudFront distribution (managed by AppSync)
- DDoS protection via AWS Shield

**Rate Limiting**:
- AppSync default: 1000 requests/second
- Throttling for excessive queries
- CloudWatch alarms for rate limit breaches


## Deployment Strategy

### Infrastructure Deployment (Terraform)

**Phase 1: AppSync API**
1. Create AppSync GraphQL API
2. Upload schema.graphql
3. Configure authorization (API_KEY + AWS_IAM)
4. Enable CloudWatch logging

**Phase 2: Data Sources**
1. Create Lambda data source for pipeline_status
2. Create Lambda data source for crawler_metrics
3. Create Lambda data source for error_rates
4. Grant AppSync permission to invoke Lambdas

**Phase 3: Resolvers**
1. Create resolvers for all Query fields
2. Create resolver for Mutation.publishCrawlerCompleted
3. Create resolver for Subscription.onCrawlerCompleted
4. Configure caching (TTL: 30 seconds)

**Phase 4: Custom Domain**
1. Create AppSync domain name association
2. Create Route 53 A record
3. Validate ACM certificate
4. Test domain resolution

**Phase 5: Crawler Integration**
1. Add appsync_client.py to crawler Lambda layers
2. Update crawler code to publish events
3. Grant crawlers IAM permission for AppSync
4. Set appsync_api_url environment variable

### Frontend Deployment

**Phase 1: Dependencies**
1. Install Apollo Client packages
2. Install GraphQL Code Generator
3. Configure codegen.yml

**Phase 2: Configuration**
1. Add AppSync endpoint to environment variables
2. Add API key to environment variables
3. Configure Apollo Client
4. Set up WebSocket link

**Phase 3: Code Generation**
1. Run GraphQL Code Generator
2. Generate TypeScript types from schema
3. Commit generated types to repository

**Phase 4: Integration**
1. Wrap app with ApolloProvider
2. Update components to use GraphQL queries
3. Add subscription components
4. Test in development

### Rollback Plan

**AppSync Rollback**:
- AppSync schema versions are immutable
- Revert to previous schema version via Terraform
- Update resolvers if needed

**Frontend Rollback**:
- Revert to previous deployment
- Frontend can fall back to REST API if needed
- Graceful degradation if WebSocket fails

### Monitoring

**CloudWatch Metrics**:
- AppSync request count
- AppSync error rate
- AppSync latency (p50, p95, p99)
- Active WebSocket connections
- Subscription event delivery rate

**CloudWatch Logs**:
- All GraphQL requests logged
- Resolver execution logs
- Lambda invocation logs
- Error logs with full context

**Alarms**:
- Error rate > 5% (warning)
- Error rate > 10% (critical)
- Latency > 3 seconds (warning)
- WebSocket connection failures (warning)

## Performance Considerations

### AppSync Performance

**Caching**:
- Server-side caching enabled (TTL: 30 seconds)
- Cache key based on query and variables
- Cache invalidation on mutations
- Reduces Lambda invocations by ~90%

**Resolver Optimization**:
- Use pipeline resolvers for complex queries
- Batch Lambda invocations where possible
- Minimize VTL template complexity

**Subscription Performance**:
- WebSocket connections are persistent
- Event delivery latency < 1 second
- Supports 1000+ concurrent connections per API

### Lambda Performance

**Cold Start Optimization**:
- Keep Lambda functions warm with CloudWatch Events
- Minimize dependencies in Lambda layers
- Use Lambda Powertools for efficient logging

**Concurrent Execution**:
- Lambda concurrency limit: 1000
- AppSync can invoke multiple Lambdas concurrently
- Use reserved concurrency for critical functions

### Frontend Performance

**Apollo Client Optimization**:
- InMemoryCache reduces network requests
- Optimistic updates for better UX
- Query deduplication
- Automatic garbage collection

**Bundle Size**:
- Apollo Client adds ~100KB to bundle
- Code split GraphQL operations
- Lazy load subscription components

## Cost Considerations

### AppSync Costs

**Query/Mutation Costs**:
- $4.00 per million requests
- Caching reduces request count significantly
- Estimated: $10-20/month for typical usage

**Real-time Updates (Subscriptions)**:
- $2.00 per million connection minutes
- $0.08 per million messages
- Estimated: $5-10/month for 10 concurrent users

**Data Transfer**:
- $0.09 per GB out
- Minimal for typical dashboard usage

### Lambda Costs

**Invocation Costs**:
- Reduced by AppSync caching
- Same Lambda functions used by REST API
- No additional cost

### Total Estimated Cost

- AppSync: $15-30/month
- Lambda: No change (existing functions)
- Data Transfer: < $5/month
- **Total: ~$20-35/month additional cost**

## Future Enhancements

### Phase 2 Features

1. **Mutations for Manual Operations**:
   - Trigger crawler manually via GraphQL
   - Pause/resume crawlers
   - Update crawler configuration

2. **Advanced Subscriptions**:
   - Subscribe to metric thresholds
   - Subscribe to error events
   - Subscribe to rate limit warnings

3. **Historical Data Queries**:
   - Query metrics over custom time ranges
   - Aggregate metrics by day/week/month
   - Compare current vs. historical performance

4. **Batch Operations**:
   - Batch multiple queries in single request
   - DataLoader pattern for efficient fetching
   - Reduce Lambda invocations

5. **GraphQL Federation**:
   - Split schema across multiple services
   - Federate with other microservices
   - Unified GraphQL gateway

### Technical Debt

1. **Testing Coverage**:
   - Increase integration test coverage
   - Add property-based tests for resolvers
   - Add load testing for subscriptions

2. **Monitoring**:
   - Add distributed tracing with X-Ray
   - Add custom CloudWatch dashboards
   - Add Sentry integration for frontend errors

3. **Documentation**:
   - Generate API documentation from schema
   - Create developer guide for GraphQL usage
   - Document subscription patterns

4. **Performance**:
   - Implement DataLoader for batching
   - Add Redis caching layer
   - Optimize VTL templates
