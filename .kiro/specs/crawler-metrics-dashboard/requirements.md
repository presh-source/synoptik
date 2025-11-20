# Requirements Document

## Introduction

This feature enhances the observability dashboard to display comprehensive crawler metrics for both repository and user crawlers in the Cold Path pipeline. The dashboard will show real-time crawler performance, ingestion progress, and error rates in a structured format matching the specified payload structure.

## Glossary

- **Cold Path**: The historical data ingestion pipeline that crawls and processes GitHub repository and user data
- **Crawler**: An automated process that fetches data from external APIs (GitHub) and stores it in the system
- **Repository Crawler**: Crawler specifically focused on fetching GitHub repository data
- **User Crawler**: Crawler specifically focused on fetching GitHub user profile data
- **Ingestion Position**: The bookmark tracking which items have been processed (lastProcessedId, totalProcessed)
- **Crawler Metrics**: Performance statistics including crawl rates, request counts, and run counts
- **Error Rate**: Percentage of failed operations in the Cold Path pipeline
- **Dashboard**: The web-based UI that displays system metrics and status
- **Backend API**: The Lambda functions that fetch and aggregate metrics from CloudWatch and DynamoDB
- **Frontend**: The React-based web application that displays the dashboard

## Requirements

### Requirement 1

**User Story:** As a system operator, I want to view real-time crawler metrics on the dashboard, so that I can monitor the health and performance of the data ingestion pipeline.

#### Acceptance Criteria

1. WHEN the dashboard loads THEN the system SHALL display the current crawler metrics for both repository and user crawlers
2. WHEN crawler metrics are displayed THEN the system SHALL show lastProcessedId, totalProcessed, totalCrawled, ratePerHour, ratePerMinute, ratePerSecond, requestCount, and runCount for each crawler type
3. WHEN the metrics are updated THEN the system SHALL refresh the display automatically every 30 seconds
4. WHEN the backend API is called THEN the system SHALL return metrics in the exact payload structure specified
5. WHEN metrics are unavailable THEN the system SHALL display zero values and show an appropriate status indicator

### Requirement 2

**User Story:** As a system operator, I want to see the ingestion progress for each crawler, so that I can track how much data has been processed.

#### Acceptance Criteria

1. WHEN viewing crawler metrics THEN the system SHALL display the lastProcessedId for each crawler type
2. WHEN viewing crawler metrics THEN the system SHALL display the totalProcessed count for each crawler type
3. WHEN the ingestion position updates THEN the system SHALL reflect the new values within 30 seconds
4. WHEN displaying numeric values THEN the system SHALL format large numbers with thousand separators for readability
5. WHEN the lastProcessedId changes THEN the system SHALL visually indicate that progress is being made

### Requirement 3

**User Story:** As a system operator, I want to see crawler performance rates, so that I can understand the throughput of the data ingestion pipeline.

#### Acceptance Criteria

1. WHEN viewing crawler metrics THEN the system SHALL display ratePerHour for each crawler type
2. WHEN viewing crawler metrics THEN the system SHALL display ratePerMinute for each crawler type
3. WHEN viewing crawler metrics THEN the system SHALL display ratePerSecond for each crawler type
4. WHEN displaying rates THEN the system SHALL format decimal values to appropriate precision (2 decimals for hour/minute, 4 decimals for second)
5. WHEN rates are zero THEN the system SHALL display "0.00" or "0.0000" rather than hiding the metric

### Requirement 4

**User Story:** As a system operator, I want to see API request and run counts, so that I can monitor crawler activity levels.

#### Acceptance Criteria

1. WHEN viewing crawler metrics THEN the system SHALL display the requestCount for each crawler type
2. WHEN viewing crawler metrics THEN the system SHALL display the runCount for each crawler type
3. WHEN displaying counts THEN the system SHALL show integer values without decimal places
4. WHEN counts exceed 1000 THEN the system SHALL format them with thousand separators
5. WHEN the crawler is inactive THEN the system SHALL display zero for requestCount and runCount

### Requirement 5

**User Story:** As a system operator, I want to see error rates for the Cold Path pipeline, so that I can quickly identify when issues occur.

#### Acceptance Criteria

1. WHEN viewing the dashboard THEN the system SHALL display the error rate for the Cold Path pipeline
2. WHEN the error rate is displayed THEN the system SHALL show it as a percentage with one decimal place
3. WHEN the error rate exceeds 5% THEN the system SHALL display a warning indicator
4. WHEN the error rate exceeds 10% THEN the system SHALL display an error indicator
5. WHEN the error rate is below 5% THEN the system SHALL display a success indicator

### Requirement 6

**User Story:** As a system operator, I want the dashboard to show the last update timestamp, so that I know how current the displayed data is.

#### Acceptance Criteria

1. WHEN metrics are displayed THEN the system SHALL show the updatedAt timestamp in ISO 8601 format
2. WHEN the timestamp is displayed THEN the system SHALL convert it to the user's local timezone
3. WHEN the data is stale (older than 5 minutes) THEN the system SHALL display a warning indicator
4. WHEN the dashboard refreshes THEN the system SHALL update the timestamp to reflect the new data fetch time
5. WHEN displaying the timestamp THEN the system SHALL show both date and time in a human-readable format

### Requirement 7

**User Story:** As a developer, I want the backend API to return metrics in a consistent payload structure, so that the frontend can reliably parse and display the data.

#### Acceptance Criteria

1. WHEN the /api/pipeline-status endpoint is called THEN the system SHALL return a JSON payload with coldPath and errorRates top-level keys
2. WHEN the coldPath object is returned THEN the system SHALL include repoCrawler and userCrawler nested objects
3. WHEN each crawler object is returned THEN the system SHALL include all required fields: lastProcessedId, totalProcessed, totalCrawled, ratePerHour, ratePerMinute, ratePerSecond, requestCount, runCount
4. WHEN numeric fields are returned THEN the system SHALL ensure integers are returned as integers and floats are returned with appropriate precision
5. WHEN the API response is serialized THEN the system SHALL use camelCase for all field names to match JavaScript conventions

### Requirement 8

**User Story:** As a system operator, I want the dashboard to handle loading and error states gracefully, so that I have a good user experience even when data is unavailable.

#### Acceptance Criteria

1. WHEN the dashboard is loading data THEN the system SHALL display a loading spinner or skeleton UI
2. WHEN an API error occurs THEN the system SHALL display an error message with details
3. WHEN data is unavailable THEN the system SHALL show placeholder values and indicate the data is not available
4. WHEN the network connection is lost THEN the system SHALL display a connection error message
5. WHEN the API recovers from an error THEN the system SHALL automatically resume displaying metrics without requiring a page refresh

### Requirement 9

**User Story:** As a system operator, I want to visually distinguish between repository and user crawler metrics, so that I can quickly identify which crawler I'm looking at.

#### Acceptance Criteria

1. WHEN displaying crawler metrics THEN the system SHALL use distinct visual styling for repository crawler and user crawler sections
2. WHEN displaying crawler metrics THEN the system SHALL use icons or labels to clearly identify each crawler type
3. WHEN displaying crawler metrics THEN the system SHALL use consistent color coding (e.g., blue for repo, green for user)
4. WHEN viewing on mobile devices THEN the system SHALL stack crawler sections vertically for readability
5. WHEN viewing on desktop THEN the system SHALL display crawler sections side-by-side when space permits

### Requirement 10

**User Story:** As a developer, I want the frontend to validate the API response structure, so that type errors are caught early and don't cause runtime failures.

#### Acceptance Criteria

1. WHEN the API response is received THEN the system SHALL validate that all required fields are present
2. WHEN a required field is missing THEN the system SHALL log a warning and use a default value
3. WHEN a field has an unexpected type THEN the system SHALL log an error and attempt to coerce the value
4. WHEN the entire response structure is invalid THEN the system SHALL display an error message to the user
5. WHEN using TypeScript THEN the system SHALL define interfaces that match the exact payload structure
