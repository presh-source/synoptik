# Implementation Plan

- [x] 1. Create AppSync infrastructure with Terraform
  - Create new Terraform module at `backend/modules/appsync/`
  - Define AppSync GraphQL API resource
  - Configure multi-auth (API_KEY + AWS_IAM)
  - Enable CloudWatch logging and metrics
  - _Requirements: 9.1, 9.5, 17.1_

- [x] 2. Define GraphQL schema
  - Create `schema.graphql` with all types, queries, mutations, and subscriptions
  - Define Query type with pipelineStatus, repoCrawler, userCrawler, errorRates
  - Define Mutation type with publishCrawlerCompleted
  - Define Subscription type with onCrawlerCompleted
  - Define all object types (PipelineStatus, CrawlerMetrics, etc.)
  - _Requirements: 1.1, 2.1, 13.1, 14.1_

- [x] 3. Create Lambda data sources for AppSync
  - Create `pipeline_status_resolver.py` Lambda function
  - Create `crawler_metrics_resolver.py` Lambda function
  - Create `error_rates_resolver.py` Lambda function
  - Configure Lambda functions to reuse existing business logic
  - Grant AppSync permission to invoke Lambda functions
  - _Requirements: 7.1, 7.2, 7.3, 16.1, 16.2_

- [x] 4. Configure AppSync resolvers
  - Create resolver for Query.pipelineStatus with VTL templates
  - Create resolver for Query.repoCrawler with VTL templates
  - Create resolver for Query.userCrawler with VTL templates
  - Create resolver for Query.errorRates with VTL templates
  - Create resolver for Mutation.publishCrawlerCompleted (NONE data source)
  - Create resolver for Subscription.onCrawlerCompleted
  - _Requirements: 1.1, 3.1, 3.2, 4.1, 13.2, 14.2_

- [x] 5. Configure AppSync caching
  - Enable server-side caching with 30-second TTL
  - Configure cache keys based on query and variables
  - Test cache hit rates
  - _Requirements: 12.3_

- [x] 6. Set up custom domain for AppSync
  - Create AppSync domain name association in Terraform
  - Create Route 53 A record pointing to AppSync
  - Configure ACM certificate for graphql.synoptik.io
  - Validate domain resolution
  - _Requirements: 9.2, 9.3_

- [x] 7. Create AppSync client helper for crawlers
  - Create `appsync_client.py` with IAM-authenticated HTTP client
  - Implement `publish_crawler_completed()` function
  - Add AWS Signature V4 authentication
  - Add retry logic with exponential backoff
  - Add error handling and logging
  - _Requirements: 14.5, 15.5_

- [x] 8. Integrate AppSync publishing into repo crawler
  - Add `appsync_client.py` to repo crawler Lambda layer
  - Update `repo_crawler.py` to call `publish_crawler_completed()` on success
  - Add dashboard_appsync_api_url environment variable
  - Grant repo crawler IAM permission for AppSync
  - Handle AppSync publish failures gracefully
  - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [x] 9. Integrate AppSync publishing into user crawler
  - Add `appsync_client.py` to user crawler Lambda layer
  - Update `user_crawler.py` to call `publish_crawler_completed()` on success
  - Add dashboard_appsync_api_url environment variable
  - Grant user crawler IAM permission for AppSync
  - Handle AppSync publish failures gracefully
  - _Requirements: 15.1, 15.2, 15.3, 15.4_

- [x] 10. Set up Apollo Client in frontend
  - Install Apollo Client packages (@apollo/client, graphql-ws)
  - Create `frontend/src/graphql/client.ts` with Apollo Client configuration
  - Configure HttpLink for queries/mutations
  - Configure WebSocketLink for subscriptions
  - Set up split link based on operation type
  - Configure InMemoryCache with type policies
  - _Requirements: 5.1, 5.2, 18.1, 18.2_

- [x] 11. Create GraphQL operations files
  - Create `frontend/src/graphql/queries.ts` with all queries
  - Create `frontend/src/graphql/subscriptions.ts` with subscriptions
  - Create `frontend/src/graphql/mutations.ts` (for future use)
  - Add GET_PIPELINE_STATUS query
  - Add GET_REPO_CRAWLER_METRICS query
  - Add ON_CRAWLER_COMPLETED subscription
  - _Requirements: 1.1, 13.1_

- [x] 12. Set up GraphQL Code Generator
  - Install @graphql-codegen packages
  - Create `frontend/codegen.yml` configuration
  - Configure to generate TypeScript types from schema
  - Add npm script to run code generator
  - Generate initial types
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 18.5_

- [x] 13. Integrate Apollo Client into React app
  - Wrap app with ApolloProvider in `main.tsx`
  - Pass apolloClient to ApolloProvider
  - Add environment variables for AppSync endpoint and API key
  - Test Apollo Client connection
  - _Requirements: 5.1_

- [x] 14. Update dashboard to use GraphQL queries
  - Update `usePipelineStatus` hook to use Apollo Client
  - Replace REST API calls with GraphQL queries
  - Keep REST API as fallback
  - Test query execution and caching
  - _Requirements: 1.1, 1.2, 5.3_

- [x] 15. Add subscription component for crawler events
  - Create `CrawlerEventNotification` component
  - Use `useSubscription` hook for onCrawlerCompleted
  - Display toast notification when crawler completes
  - Refetch pipeline status on subscription event
  - Handle subscription errors gracefully
  - _Requirements: 13.2, 13.3, 18.3, 18.4_

- [x] 16. Configure IAM roles and policies
  - Create IAM role for AppSync to invoke Lambda
  - Create IAM policy for crawlers to publish to AppSync
  - Attach policies to crawler Lambda execution roles
  - Follow principle of least privilege
  - _Requirements: 16.5, 17.1, 17.2, 17.5_

- [x] 17. Add environment variables
  - Add dashboard_appsync_api_url to crawler Lambdas
  - Add VITE_DASHBOARD_APPSYNC_API_URL to frontend
  - Add DASHBOARD_APPSYNC_API_KEY to frontend
  - Add DASHBOARD_APPSYNC_REALTIME_URL to frontend
  - Store API key in AWS Secrets Manager
  - _Requirements: 9.1_

- [x] 18. Test end-to-end flow
  - Manually trigger repo crawler
  - Verify crawler publishes event to AppSync
  - Verify frontend receives subscription event
  - Verify UI updates with new data
  - Test with both repo and user crawlers
  - _Requirements: 13.3, 14.3, 15.3_

- [ ] 19. Add CloudWatch monitoring
  - Create CloudWatch dashboard for AppSync metrics
  - Add alarms for error rate > 5%
  - Add alarms for latency > 3 seconds
  - Add alarms for WebSocket connection failures
  - Configure SNS notifications for alarms
  - _Requirements: 9.5_

- [ ] 20. Update documentation
  - Document GraphQL schema in README
  - Add examples of queries and subscriptions
  - Document how to run code generator
  - Document environment variable setup
  - Add troubleshooting guide
  - _Requirements: 2.2, 6.2_

- [ ] 21. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
