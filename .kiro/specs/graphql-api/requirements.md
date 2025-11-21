# Requirements Document

## Introduction

This feature adds a GraphQL API using AWS AppSync to the Synoptik observability platform alongside the existing REST API. The GraphQL API will provide a flexible, type-safe interface for querying pipeline metrics, crawler status, and error rates, with real-time subscriptions for crawler completion events. AppSync will be configured with a custom domain name and will integrate with existing Lambda data sources. This implementation will coexist with the current REST endpoints, allowing for gradual adoption and migration.

## Glossary

- **GraphQL**: A query language for APIs that allows clients to request exactly the data they need
- **Schema**: The GraphQL type system that defines the structure of available data and operations
- **Query**: A read operation in GraphQL to fetch data
- **Mutation**: A write operation in GraphQL to modify data or trigger events
- **Subscription**: A real-time GraphQL operation that pushes updates to clients when events occur
- **Resolver**: A function that handles fetching data for a specific field in the GraphQL schema
- **AppSync**: AWS managed GraphQL service with built-in subscriptions, caching, and authorization
- **Data Source**: AppSync's connection to backend services (Lambda, DynamoDB, HTTP endpoints)
- **Apollo Client**: A comprehensive GraphQL client for React applications with subscription support
- **WebSocket**: Protocol used by AppSync for real-time subscriptions
- **Custom Domain**: A branded domain name (e.g., graphql.synoptik.io) for the AppSync API
- **VTL (Velocity Template Language)**: Template language used by AppSync for request/response mapping

## Requirements

### Requirement 1

**User Story:** As a developer, I want to query pipeline metrics using GraphQL, so that I can request only the specific data fields I need.

#### Acceptance Criteria

1. WHEN a GraphQL query is sent to `/api/graphql` THEN the system SHALL process the query and return the requested data
2. WHEN the query requests specific fields THEN the system SHALL return only those fields and omit unrequested fields
3. WHEN the query is malformed THEN the system SHALL return a GraphQL error response with details
4. WHEN the query requests nested data THEN the system SHALL resolve all nested fields correctly
5. WHEN multiple queries are batched THEN the system SHALL process all queries and return results for each

### Requirement 2

**User Story:** As a frontend developer, I want a strongly-typed GraphQL schema, so that I can have autocomplete and type safety in my queries.

#### Acceptance Criteria

1. WHEN the GraphQL schema is defined THEN the system SHALL use Python type hints to generate the schema
2. WHEN introspection is queried THEN the system SHALL return the complete schema definition
3. WHEN a field type is defined THEN the system SHALL enforce that type at runtime
4. WHEN nullable fields are defined THEN the system SHALL clearly indicate which fields are optional
5. WHEN the schema is updated THEN the system SHALL automatically reflect changes in introspection

### Requirement 3

**User Story:** As a developer, I want to query crawler metrics for specific crawler types, so that I can fetch only repo or user crawler data as needed.

#### Acceptance Criteria

1. WHEN querying `repoCrawler` THEN the system SHALL return only repository crawler metrics
2. WHEN querying `userCrawler` THEN the system SHALL return only user crawler metrics
3. WHEN querying both crawlers THEN the system SHALL return metrics for both in a single request
4. WHEN querying crawler fields THEN the system SHALL support selecting specific metric fields
5. WHEN crawler data is unavailable THEN the system SHALL return null or default values as appropriate

### Requirement 4

**User Story:** As a developer, I want to query error rates independently, so that I can monitor system health without fetching all metrics.

#### Acceptance Criteria

1. WHEN querying `errorRates` THEN the system SHALL return error rate data without requiring other fields
2. WHEN querying `coldPath` error rate THEN the system SHALL return the percentage as a float
3. WHEN error rate data is unavailable THEN the system SHALL return 0.0 as the default
4. WHEN querying error rates with time ranges THEN the system SHALL support filtering by time period
5. WHEN error rates exceed thresholds THEN the system SHALL return the raw values without modification

### Requirement 5

**User Story:** As a frontend developer, I want to use Apollo Client in React, so that I can leverage caching, optimistic updates, and automatic refetching.

#### Acceptance Criteria

1. WHEN Apollo Client is configured THEN the system SHALL connect to the GraphQL endpoint
2. WHEN a query is executed THEN Apollo Client SHALL cache the results automatically
3. WHEN the same query is executed again THEN Apollo Client SHALL return cached data if valid
4. WHEN cache is invalidated THEN Apollo Client SHALL refetch data from the server
5. WHEN network errors occur THEN Apollo Client SHALL handle errors gracefully and provide error states

### Requirement 6

**User Story:** As a developer, I want GraphQL Playground or GraphiQL available in development, so that I can explore the API and test queries interactively.

#### Acceptance Criteria

1. WHEN accessing the GraphQL endpoint in a browser THEN the system SHALL serve an interactive GraphQL IDE
2. WHEN the IDE loads THEN the system SHALL display the schema documentation automatically
3. WHEN typing queries THEN the IDE SHALL provide autocomplete based on the schema
4. WHEN executing queries THEN the IDE SHALL display results in a formatted view
5. WHEN the environment is production THEN the system SHALL disable the GraphQL IDE for security

### Requirement 7

**User Story:** As a backend developer, I want resolvers to reuse existing business logic, so that I maintain consistency between REST and GraphQL APIs.

#### Acceptance Criteria

1. WHEN a GraphQL resolver executes THEN the system SHALL call the same functions used by REST endpoints
2. WHEN fetching crawler metrics THEN the system SHALL use `get_crawler_metrics_from_cloudwatch()`
3. WHEN fetching cold path status THEN the system SHALL use `get_cold_path_status()`
4. WHEN fetching error rates THEN the system SHALL use `get_error_rates()`
5. WHEN business logic changes THEN both REST and GraphQL SHALL reflect the changes automatically

### Requirement 8

**User Story:** As a developer, I want proper error handling in GraphQL, so that I can debug issues and handle failures gracefully.

#### Acceptance Criteria

1. WHEN a resolver throws an exception THEN the system SHALL return a GraphQL error with a message
2. WHEN CloudWatch queries fail THEN the system SHALL return partial data with errors for failed fields
3. WHEN DynamoDB queries fail THEN the system SHALL return default values and log errors
4. WHEN validation fails THEN the system SHALL return validation errors before executing resolvers
5. WHEN errors occur THEN the system SHALL log errors to Sentry with full context

### Requirement 9

**User Story:** As a DevOps engineer, I want GraphQL deployed via AWS AppSync with a custom domain, so that it provides a branded, managed GraphQL service.

#### Acceptance Criteria

1. WHEN AppSync is deployed THEN the system SHALL create an AppSync GraphQL API with the defined schema
2. WHEN a custom domain is configured THEN the system SHALL use a branded domain name (e.g., graphql.synoptik.io)
3. WHEN the custom domain is accessed THEN the system SHALL route requests to the AppSync API
4. WHEN CORS is configured THEN the system SHALL allow requests from the frontend domain
5. WHEN monitoring is enabled THEN the system SHALL publish CloudWatch metrics and logs for all GraphQL operations

### Requirement 10

**User Story:** As a frontend developer, I want TypeScript types generated from the GraphQL schema, so that I have type safety in my React components.

#### Acceptance Criteria

1. WHEN the schema is defined THEN the system SHALL generate TypeScript types automatically
2. WHEN queries are written THEN the system SHALL provide typed query results
3. WHEN variables are used THEN the system SHALL validate variable types at compile time
4. WHEN the schema changes THEN the system SHALL regenerate TypeScript types
5. WHEN using generated types THEN the system SHALL provide IDE autocomplete for all fields

### Requirement 11

**User Story:** As a developer, I want to query historical metrics with time ranges, so that I can analyze trends over different periods.

#### Acceptance Criteria

1. WHEN querying with a time range THEN the system SHALL accept start and end timestamps
2. WHEN no time range is specified THEN the system SHALL default to the last 1 hour
3. WHEN the time range is invalid THEN the system SHALL return a validation error
4. WHEN querying historical data THEN the system SHALL aggregate metrics over the specified period
5. WHEN the time range is too large THEN the system SHALL limit the range to prevent performance issues

### Requirement 12

**User Story:** As a system operator, I want GraphQL queries to be performant, so that the dashboard remains responsive.

#### Acceptance Criteria

1. WHEN a query is executed THEN the system SHALL complete within 3 seconds for typical queries
2. WHEN multiple fields are requested THEN the system SHALL batch CloudWatch queries where possible
3. WHEN AppSync caching is enabled THEN the system SHALL serve cached responses within 100ms
4. WHEN resolvers execute THEN the system SHALL use Lambda data sources for complex operations
5. WHEN query complexity is high THEN the system SHALL limit query depth to prevent abuse

### Requirement 13

**User Story:** As a frontend developer, I want to subscribe to crawler completion events, so that the dashboard updates automatically when crawlers finish running.

#### Acceptance Criteria

1. WHEN a crawler completes THEN the system SHALL publish a `crawlerCompleted` event to AppSync
2. WHEN a client subscribes to `onCrawlerCompleted` THEN the system SHALL establish a WebSocket connection
3. WHEN a crawler completion event is published THEN all subscribed clients SHALL receive the event immediately
4. WHEN the event includes crawler type THEN the system SHALL allow filtering subscriptions by crawler type (repo or user)
5. WHEN the WebSocket connection drops THEN the system SHALL automatically reconnect and resume subscriptions

### Requirement 14

**User Story:** As a developer, I want the repo crawler to publish events when it completes, so that subscribers receive real-time updates.

#### Acceptance Criteria

1. WHEN the repo crawler finishes successfully THEN the system SHALL publish a mutation to AppSync with completion data
2. WHEN the mutation is executed THEN the system SHALL include start_id, end_id, repositories_fetched, and total_processed
3. WHEN the mutation completes THEN AppSync SHALL trigger the subscription for all connected clients
4. WHEN the crawler fails THEN the system SHALL publish an error event with failure details
5. WHEN publishing events THEN the system SHALL use the AppSync HTTP endpoint with IAM authentication

### Requirement 15

**User Story:** As a developer, I want the user crawler to publish events when it completes, so that subscribers receive real-time updates.

#### Acceptance Criteria

1. WHEN the user crawler finishes successfully THEN the system SHALL publish a mutation to AppSync with completion data
2. WHEN the mutation is executed THEN the system SHALL include start_id, end_id, users_fetched, and total_processed
3. WHEN the mutation completes THEN AppSync SHALL trigger the subscription for all connected clients
4. WHEN the crawler fails THEN the system SHALL publish an error event with failure details
5. WHEN publishing events THEN the system SHALL use the AppSync HTTP endpoint with IAM authentication

### Requirement 16

**User Story:** As a DevOps engineer, I want AppSync to use Lambda data sources, so that I can reuse existing business logic.

#### Acceptance Criteria

1. WHEN AppSync resolvers are configured THEN the system SHALL use Lambda functions as data sources
2. WHEN a query is executed THEN AppSync SHALL invoke the appropriate Lambda function
3. WHEN Lambda returns data THEN AppSync SHALL map the response to the GraphQL schema
4. WHEN Lambda throws an error THEN AppSync SHALL return a GraphQL error to the client
5. WHEN configuring data sources THEN the system SHALL grant AppSync permission to invoke Lambda functions

### Requirement 17

**User Story:** As a security engineer, I want AppSync to use IAM authorization, so that only authorized services can publish events.

#### Acceptance Criteria

1. WHEN AppSync is configured THEN the system SHALL use IAM as the authorization mode
2. WHEN crawlers publish events THEN the system SHALL validate IAM credentials
3. WHEN frontend clients query data THEN the system SHALL use API key or Cognito authorization
4. WHEN unauthorized requests are made THEN the system SHALL return 401 Unauthorized errors
5. WHEN configuring IAM roles THEN the system SHALL follow the principle of least privilege

### Requirement 18

**User Story:** As a frontend developer, I want Apollo Client configured for AppSync subscriptions, so that I can receive real-time updates in React components.

#### Acceptance Criteria

1. WHEN Apollo Client is configured THEN the system SHALL use the AppSync WebSocket endpoint for subscriptions
2. WHEN a subscription is created THEN Apollo Client SHALL establish a WebSocket connection
3. WHEN subscription data arrives THEN Apollo Client SHALL update the cache automatically
4. WHEN the component unmounts THEN Apollo Client SHALL clean up the subscription
5. WHEN using subscriptions THEN the system SHALL provide TypeScript types for subscription data
