# Design Document

## Overview

This design enhances the existing observability dashboard to display comprehensive crawler metrics in a structured, real-time format. The solution builds upon the existing Lambda functions (`pipeline_status.py` and `cloudwatch_metrics.py`) and React components (`CrawlerMetricsCard`, `ColdPathStatusCard`) to ensure the payload structure matches the specified format exactly.

The system follows a three-tier architecture:
1. **Data Layer**: CloudWatch metrics and DynamoDB state
2. **API Layer**: Lambda functions that aggregate and format metrics
3. **Presentation Layer**: React components that display metrics with auto-refresh

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend (React)                      │
│  ┌──────────────────┐         ┌──────────────────────────┐ │
│  │ PipelineStatus   │────────▶│  CrawlerMetricsCard      │ │
│  │ Page             │         │  - Repo Crawler Display  │ │
│  │                  │         │  - User Crawler Display  │ │
│  └────────┬─────────┘         └──────────────────────────┘ │
│           │                                                  │
│           │ usePipelineStatus Hook (30s polling)            │
└───────────┼──────────────────────────────────────────────────┘
            │
            │ HTTPS GET /api/pipeline-status
            ▼
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway (REST API)                    │
└───────────┬─────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│              Lambda: pipeline_status.py                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ get_cold_path_status()                               │  │
│  │  ├─ Query DynamoDB for bookmark                      │  │
│  │  ├─ get_crawler_metrics_from_cloudwatch("repo")      │  │
│  │  └─ get_crawler_metrics_from_cloudwatch("user")      │  │
│  │                                                        │  │
│  │ get_error_rates()                                     │  │
│  │  └─ Query CloudWatch for error metrics               │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────┬─────────────────────────────────────────────────┘
            │
            ├──────────────────┬──────────────────┐
            ▼                  ▼                  ▼
┌──────────────────┐  ┌──────────────┐  ┌──────────────────┐
│   DynamoDB       │  │  CloudWatch  │  │  CloudWatch      │
│   (Bookmarks)    │  │  (Metrics)   │  │  (Errors)        │
│                  │  │              │  │                  │
│  - state_key     │  │  - Items     │  │  - Lambda        │
│  - last_proc_id  │  │    Crawled   │  │    Errors        │
│  - total_proc    │  │  - API Reqs  │  │  - Invocations   │
│  - updated_at    │  │  - Runs      │  │                  │
└──────────────────┘  └──────────────┘  └──────────────────┘
```

### Data Flow

1. **Frontend Polling**: React hook polls `/api/pipeline-status` every 30 seconds
2. **Lambda Aggregation**: Lambda function queries DynamoDB and CloudWatch
3. **Metric Calculation**: Lambda calculates rates (per hour, minute, second)
4. **Response Formatting**: Lambda formats response to match exact payload structure
5. **Frontend Display**: React components render metrics with visual indicators

## Components and Interfaces

### Backend Components

#### 1. Lambda Function: `pipeline_status.py`

**Purpose**: Aggregate crawler metrics from CloudWatch and DynamoDB

**Key Functions**:

```python
def get_crawler_metrics_from_cloudwatch(
    crawler_type: str,
    time_period_hours: int = 1
) -> dict:
    """
    Fetch metrics for a specific crawler type from CloudWatch.
    
    Args:
        crawler_type: "repo" or "user"
        time_period_hours: Lookback period (default 1 hour)
    
    Returns:
        {
            "totalCrawled": int,
            "ratePerHour": float,
            "ratePerMinute": float,
            "ratePerSecond": float,
            "requestCount": int,
            "runCount": int
        }
    """

def get_cold_path_status() -> dict:
    """
    Get Cold Path status including crawler metrics.
    
    Returns:
        {
            "lastProcessedId": int,
            "totalProcessed": int,
            "updatedAt": str (ISO 8601),
            "repoCrawler": {
                "lastProcessedId": int,
                "totalProcessed": int,
                "totalCrawled": int,
                "ratePerHour": float,
                "ratePerMinute": float,
                "ratePerSecond": float,
                "requestCount": int,
                "runCount": int
            },
            "userCrawler": { ... same structure ... }
        }
    """

def get_error_rates() -> dict:
    """
    Calculate error rates for Cold Path pipeline.
    
    Returns:
        {
            "coldPath": float (percentage)
        }
    """

def lambda_handler(event, context) -> dict:
    """
    API Gateway handler.
    
    Returns:
        {
            "statusCode": 200,
            "headers": { ... CORS headers ... },
            "body": JSON string of:
                {
                    "coldPath": { ... from get_cold_path_status() ... },
                    "errorRates": { ... from get_error_rates() ... }
                }
        }
    """
```

#### 2. CloudWatch Metrics

**Custom Metrics Published**:
- Namespace: `{ProjectName}/ColdPath`
- Dimensions: `CrawlerType` (repo | user)
- Metrics:
  - `ItemsCrawled` (Count)
  - `APIRequests` (Count)
  - `CrawlerRuns` (Count)

**AWS Lambda Metrics Used**:
- Namespace: `AWS/Lambda`
- Metrics:
  - `Errors` (Count)
  - `Invocations` (Count)

#### 3. DynamoDB Table

**Table**: Cold Path state table
**Key**: `state_key = "bookmark"`
**Attributes**:
- `last_processed_id` (Number)
- `total_processed` (Number)
- `updated_at` (String, ISO 8601)

### Frontend Components

#### 1. React Hook: `usePipelineStatus`

**Purpose**: Fetch and manage pipeline status data with auto-refresh

```typescript
interface PipelineStatusData {
  coldPath: {
    lastProcessedId: number
    totalProcessed: number
    updatedAt: string
    repoCrawler: CrawlerMetrics
    userCrawler: CrawlerMetrics
  }
  errorRates: {
    coldPath: number
  }
}

function usePipelineStatus(refreshInterval: number = 30000) {
  // Uses React Query for data fetching
  // Returns: { data, isLoading, error, isError }
}
```

#### 2. Component: `CrawlerMetricsCard`

**Purpose**: Display crawler metrics for both repo and user crawlers

**Props**:
```typescript
interface CrawlerMetricsProps {
  repoCrawler?: CrawlerMetrics
  userCrawler?: CrawlerMetrics
}
```

**Visual Structure**:
```
┌─────────────────────────────────────────────────┐
│  Crawler Performance Metrics                    │
├─────────────────────────────────────────────────┤
│  Repository Crawler                             │
│  ┌─────────────────┬─────────────────┐         │
│  │ Total Crawled   │ Rate/Hour       │         │
│  │ 34,538,600      │ 1,234.56        │         │
│  ├─────────────────┼─────────────────┤         │
│  │ Rate/Minute     │ Rate/Second     │         │
│  │ 20.58           │ 0.3430          │         │
│  ├─────────────────┼─────────────────┤         │
│  │ API Requests    │ Crawler Runs    │         │
│  │ 5,678           │ 123             │         │
│  └─────────────────┴─────────────────┘         │
│                                                  │
│  User Crawler                                   │
│  ┌─────────────────┬─────────────────┐         │
│  │ ... same layout ...                │         │
│  └─────────────────┴─────────────────┘         │
└─────────────────────────────────────────────────┘
```

#### 3. Component: `ColdPathStatusCard`

**Purpose**: Display ingestion progress and error rates

**Props**:
```typescript
interface ColdPathStatusProps {
  data: {
    lastProcessedId: number
    totalProcessed: number
    updatedAt: string
    repoCrawler: CrawlerMetrics
    userCrawler: CrawlerMetrics
  }
}
```

**Visual Structure**:
```
┌─────────────────────────────────────────────────┐
│  Cold Path Ingestion Status                     │
├─────────────────────────────────────────────────┤
│  Last Processed ID: 71,280,462                  │
│  Total Processed:   34,538,600                  │
│  Updated At:        Nov 20, 2025 4:41 AM        │
│                                                  │
│  ● Status: Active                               │
└─────────────────────────────────────────────────┘
```

## Data Models

### TypeScript Interfaces

```typescript
// Core crawler metrics structure
interface CrawlerMetrics {
  lastProcessedId: number
  totalProcessed: number
  totalCrawled: number
  ratePerHour: number
  ratePerMinute: number
  ratePerSecond: number
  requestCount: number
  runCount: number
}

// Cold Path status structure
interface ColdPathStatus {
  lastProcessedId: number
  totalProcessed: number
  updatedAt: string  // ISO 8601 format
  repoCrawler: CrawlerMetrics
  userCrawler: CrawlerMetrics
}

// Error rates structure
interface ErrorRates {
  coldPath: number  // Percentage (0-100)
}

// Complete API response
interface PipelineStatusResponse {
  coldPath: ColdPathStatus
  errorRates: ErrorRates
}
```

### Python Data Structures

```python
# Type hints for Lambda function returns
from typing import TypedDict

class CrawlerMetrics(TypedDict):
    lastProcessedId: int
    totalProcessed: int
    totalCrawled: int
    ratePerHour: float
    ratePerMinute: float
    ratePerSecond: float
    requestCount: int
    runCount: int

class ColdPathStatus(TypedDict):
    lastProcessedId: int
    totalProcessed: int
    updatedAt: str
    repoCrawler: CrawlerMetrics
    userCrawler: CrawlerMetrics

class ErrorRates(TypedDict):
    coldPath: float

class PipelineStatusResponse(TypedDict):
    coldPath: ColdPathStatus
    errorRates: ErrorRates
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property 1: All required crawler fields are displayed
*For any* crawler metrics object rendered in the UI, all 8 required fields (lastProcessedId, totalProcessed, totalCrawled, ratePerHour, ratePerMinute, ratePerSecond, requestCount, runCount) should be present in the DOM.
**Validates: Requirements 1.2**

### Property 2: API response contains required structure
*For any* successful API response from `/api/pipeline-status`, the JSON payload should contain both `coldPath` and `errorRates` as top-level keys.
**Validates: Requirements 7.1**

### Property 3: ColdPath object contains crawler objects
*For any* `coldPath` object in the API response, it should contain both `repoCrawler` and `userCrawler` as nested objects.
**Validates: Requirements 7.2**

### Property 4: Crawler objects are complete
*For any* crawler object (repoCrawler or userCrawler) in the API response, it should contain all 8 required fields: lastProcessedId, totalProcessed, totalCrawled, ratePerHour, ratePerMinute, ratePerSecond, requestCount, runCount.
**Validates: Requirements 7.3**

### Property 5: Large numbers are formatted with separators
*For any* number >= 1000 displayed in the UI, the formatted string should contain thousand separators (commas).
**Validates: Requirements 2.4**

### Property 6: Rates have correct decimal precision
*For any* rate value displayed, ratePerHour and ratePerMinute should have exactly 2 decimal places, and ratePerSecond should have exactly 4 decimal places.
**Validates: Requirements 3.4**

### Property 7: Counts are formatted as integers
*For any* count field (requestCount, runCount, totalProcessed, totalCrawled, lastProcessedId) displayed in the UI, the formatted string should not contain a decimal point.
**Validates: Requirements 4.3**

### Property 8: Error rate formatted with one decimal
*For any* error rate value displayed, it should be formatted as a percentage with exactly 1 decimal place.
**Validates: Requirements 5.2**

### Property 9: Error rate warning indicator
*For any* error rate value > 5% and <= 10%, a warning indicator should be displayed.
**Validates: Requirements 5.3**

### Property 10: Error rate error indicator
*For any* error rate value > 10%, an error indicator should be displayed.
**Validates: Requirements 5.4**

### Property 11: Error rate success indicator
*For any* error rate value < 5%, a success indicator should be displayed.
**Validates: Requirements 5.5**

### Property 12: Timestamp timezone conversion
*For any* ISO 8601 timestamp in the API response, when displayed in the UI it should be converted to the user's local timezone.
**Validates: Requirements 6.2**

### Property 13: Stale data warning
*For any* timestamp that is older than 5 minutes from the current time, a warning indicator should be displayed.
**Validates: Requirements 6.3**

### Property 14: Timestamp includes date and time
*For any* timestamp displayed in the UI, the formatted string should include both date and time components in human-readable format.
**Validates: Requirements 6.5**

### Property 15: Numeric types are correct
*For any* numeric field in the API response, integer fields (lastProcessedId, totalProcessed, totalCrawled, requestCount, runCount) should be JSON integers, and rate fields should be JSON floats.
**Validates: Requirements 7.4**

### Property 16: Field names are camelCase
*For any* field name in the API response, it should follow camelCase naming convention (first word lowercase, subsequent words capitalized, no underscores).
**Validates: Requirements 7.5**

### Property 17: Error recovery updates UI
*For any* sequence where an API call fails followed by a successful API call, the UI should automatically update to display the new data without requiring a page refresh.
**Validates: Requirements 8.5**

### Property 18: Response validation checks required fields
*For any* API response received by the frontend, the validation function should verify that all required fields are present before attempting to render.
**Validates: Requirements 10.1**

### Property 19: Missing fields use defaults
*For any* API response missing a required field, the system should log a warning and use a default value (0 for numbers, empty string for strings).
**Validates: Requirements 10.2**

### Property 20: Type coercion for wrong types
*For any* field in the API response that has an unexpected type, the system should log an error and attempt to coerce the value to the expected type.
**Validates: Requirements 10.3**

## Error Handling

### Backend Error Handling

**CloudWatch Query Failures**:
- If CloudWatch metrics are unavailable, return zero values for all metrics
- Log error to Sentry with context
- Continue processing other metrics

**DynamoDB Query Failures**:
- If bookmark is unavailable, return lastProcessedId: 0, totalProcessed: 0
- Log error to Sentry
- Continue with CloudWatch metrics

**Partial Failures**:
- If one crawler type fails, still return data for the other
- Include error information in response (optional `error` field)

**Rate Limiting**:
- CloudWatch API has rate limits
- Implement exponential backoff for retries
- Cache metrics for 30 seconds to reduce API calls

### Frontend Error Handling

**API Errors**:
- Display error message with retry button
- Show last successful data if available
- Log error to console

**Network Errors**:
- Display "Connection lost" message
- Automatically retry when connection restored
- Show offline indicator

**Invalid Data**:
- Validate response structure
- Use default values for missing fields
- Log validation errors
- Display partial data if possible

**Loading States**:
- Show skeleton UI while loading
- Timeout after 30 seconds
- Allow manual refresh

## Testing Strategy

### Unit Testing

**Backend (Python)**:
- Test `get_crawler_metrics_from_cloudwatch()` with mocked CloudWatch responses
- Test `get_cold_path_status()` with mocked DynamoDB responses
- Test `get_error_rates()` with mocked CloudWatch responses
- Test rate calculations (per hour, minute, second)
- Test error handling for missing data
- Test JSON serialization of response

**Frontend (TypeScript/React)**:
- Test `usePipelineStatus` hook with mocked API responses
- Test `CrawlerMetricsCard` component rendering
- Test `ColdPathStatusCard` component rendering
- Test number formatting functions
- Test timestamp formatting functions
- Test error state rendering
- Test loading state rendering

### Property-Based Testing

We will use **Hypothesis** for Python and **fast-check** for TypeScript to implement property-based tests.

**Backend Properties**:
- Property 2: API response structure
- Property 3: ColdPath object structure
- Property 4: Crawler object completeness
- Property 15: Numeric type correctness
- Property 16: CamelCase field names

**Frontend Properties**:
- Property 1: All fields displayed
- Property 5: Number formatting with separators
- Property 6: Rate decimal precision
- Property 7: Integer formatting
- Property 8: Error rate formatting
- Property 9-11: Error rate indicators
- Property 12: Timezone conversion
- Property 13: Stale data warning
- Property 14: Timestamp formatting
- Property 17: Error recovery
- Property 18-20: Response validation

### Integration Testing

**End-to-End Flow**:
1. Mock CloudWatch and DynamoDB
2. Call Lambda function
3. Verify response structure
4. Render React components with response
5. Verify all metrics displayed correctly

**Auto-Refresh Testing**:
1. Render dashboard
2. Wait 30 seconds
3. Verify API called again
4. Verify UI updated

**Error Recovery Testing**:
1. Mock API error
2. Verify error message displayed
3. Mock successful response
4. Verify UI recovered automatically

### Manual Testing Checklist

- [ ] Dashboard loads and displays metrics
- [ ] Both repo and user crawler sections visible
- [ ] All 8 fields displayed for each crawler
- [ ] Numbers formatted with thousand separators
- [ ] Rates have correct decimal precision
- [ ] Error rate indicator shows correct color
- [ ] Timestamp displays in local timezone
- [ ] Auto-refresh works every 30 seconds
- [ ] Loading state shows spinner
- [ ] Error state shows error message
- [ ] Mobile layout stacks vertically
- [ ] Desktop layout shows side-by-side

## Performance Considerations

### Backend Performance

**CloudWatch Query Optimization**:
- Use 1-hour period to reduce data points
- Query metrics in parallel using asyncio
- Cache results for 30 seconds

**DynamoDB Query Optimization**:
- Use consistent reads for latest data
- Single GetItem operation (not Scan)
- Minimal data transfer

**Lambda Cold Start**:
- Keep function warm with CloudWatch Events
- Minimize dependencies in Lambda layer
- Use Lambda Powertools for efficient logging

### Frontend Performance

**React Optimization**:
- Use React.memo for components
- Memoize expensive calculations
- Avoid unnecessary re-renders

**API Call Optimization**:
- Use React Query for caching
- Deduplicate simultaneous requests
- Background refetch on window focus

**Bundle Size**:
- Code split dashboard page
- Lazy load components
- Tree-shake unused dependencies

## Security Considerations

### Backend Security

**IAM Permissions**:
- Lambda execution role has minimal permissions
- Read-only access to CloudWatch and DynamoDB
- No write permissions

**API Gateway**:
- CORS configured for specific origins
- Rate limiting enabled
- API key optional (can be added)

**Data Exposure**:
- No sensitive data in metrics
- No PII in responses
- Aggregate data only

### Frontend Security

**XSS Prevention**:
- React escapes all rendered content
- No dangerouslySetInnerHTML used
- Sanitize any user input

**API Security**:
- HTTPS only
- CORS headers validated
- No credentials in frontend code

## Deployment Strategy

### Backend Deployment

1. Deploy Lambda function updates
2. Verify CloudWatch metrics are being published
3. Test API endpoint manually
4. Monitor Lambda errors in CloudWatch

### Frontend Deployment

1. Build production bundle
2. Upload to S3
3. Invalidate CloudFront cache
4. Verify dashboard loads correctly
5. Monitor browser console for errors

### Rollback Plan

**Backend**:
- Revert Lambda function to previous version
- Lambda versions are immutable

**Frontend**:
- Revert S3 objects to previous version
- S3 versioning enabled
- CloudFront cache invalidation

## Monitoring and Observability

### Metrics to Monitor

**Backend**:
- Lambda invocation count
- Lambda error rate
- Lambda duration
- CloudWatch API call count
- DynamoDB read capacity

**Frontend**:
- Page load time
- API response time
- Error rate (from browser logs)
- User engagement (time on page)

### Alerts

**Critical**:
- Lambda error rate > 10%
- API response time > 5 seconds
- CloudWatch API throttling

**Warning**:
- Lambda error rate > 5%
- API response time > 2 seconds
- Stale data (> 5 minutes old)

### Logging

**Backend**:
- All errors logged to Sentry
- CloudWatch Logs for debugging
- Structured logging with context

**Frontend**:
- Console errors in development
- Sentry for production errors
- User actions logged for analytics

## Future Enhancements

### Phase 2 Features

1. **Historical Trends**:
   - Graph crawler rates over time
   - Compare current vs. historical performance
   - Identify patterns and anomalies

2. **Alerting**:
   - Email/Slack notifications for errors
   - Threshold-based alerts
   - Anomaly detection

3. **Filtering**:
   - Time range selection
   - Crawler type filtering
   - Metric comparison

4. **Export**:
   - Download metrics as CSV
   - Generate PDF reports
   - API for programmatic access

5. **Real-time Updates**:
   - WebSocket for live updates
   - No polling delay
   - Push notifications

### Technical Debt

1. **Testing Coverage**:
   - Increase unit test coverage to 90%
   - Add more integration tests
   - Implement visual regression testing

2. **Performance**:
   - Implement server-side caching
   - Optimize CloudWatch queries
   - Reduce bundle size

3. **Accessibility**:
   - Add ARIA labels
   - Keyboard navigation
   - Screen reader support

4. **Documentation**:
   - API documentation
   - Component storybook
   - Deployment runbook
