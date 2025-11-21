# usePipelineStatus Hook - GraphQL Integration

## Summary of Changes

The `usePipelineStatus` hook has been updated to use GraphQL as the primary data source with REST API as a fallback mechanism.

## Key Features Implemented

### 1. GraphQL as Primary Data Source (Requirement 1.1)
- Uses Apollo Client's `useGetPipelineStatusQuery` hook
- Executes the `GetPipelineStatus` GraphQL query
- Leverages AppSync's GraphQL API endpoint

### 2. Selective Field Fetching (Requirement 1.2)
- GraphQL query explicitly requests only needed fields
- Reduces data transfer compared to REST API
- Query structure defined in `frontend/src/graphql/queries.ts`

### 3. Apollo Client Caching (Requirement 5.3)
- Uses `cache-and-network` fetch policy
- Shows cached data immediately while fetching fresh data in background
- Improves perceived performance and user experience
- Automatic cache updates on new data

### 4. REST API Fallback
- Maintains existing REST API integration
- Automatically falls back to REST if GraphQL fails
- Ensures high availability and reliability
- Logs fallback events for monitoring

### 5. Polling and Auto-refresh
- 30-second polling interval (configurable)
- Continues polling in background tabs
- Consistent behavior between GraphQL and REST modes

### 6. Error Handling
- Graceful degradation when GraphQL fails
- Comprehensive error logging
- Maintains user experience during failures
- Retry logic with exponential backoff for REST fallback

## Architecture

```
┌─────────────────────────────────────┐
│   usePipelineStatus Hook            │
│                                     │
│  ┌───────────────────────────────┐ │
│  │  Primary: GraphQL (Apollo)    │ │
│  │  - useGetPipelineStatusQuery  │ │
│  │  - pollInterval: 30s          │ │
│  │  - cache-and-network policy   │ │
│  └───────────────┬───────────────┘ │
│                  │                  │
│                  │ On Error         │
│                  ▼                  │
│  ┌───────────────────────────────┐ │
│  │  Fallback: REST API           │ │
│  │  - useQuery (React Query)     │ │
│  │  - pipelineApi.getStatus()    │ │
│  │  - Retry with backoff         │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

## Data Flow

1. **Initial Load**:
   - Apollo Client checks cache
   - If cache exists, returns cached data immediately
   - Simultaneously fetches fresh data from GraphQL API
   - Updates cache and UI when fresh data arrives

2. **Polling**:
   - Every 30 seconds, Apollo Client refetches data
   - Cache is updated automatically
   - React components re-render with new data

3. **Error Scenario**:
   - GraphQL query fails
   - Hook logs warning message
   - REST API query is enabled
   - Data fetched from REST endpoint
   - User sees data without interruption

## Benefits

### Performance
- **Faster initial loads**: Cache-and-network policy shows cached data instantly
- **Reduced bandwidth**: GraphQL fetches only requested fields
- **Optimized polling**: Apollo Client manages polling efficiently

### Reliability
- **High availability**: Automatic fallback to REST API
- **Graceful degradation**: System continues working even if GraphQL fails
- **Error recovery**: Retry logic ensures transient failures are handled

### Developer Experience
- **Type safety**: Generated TypeScript types from GraphQL schema
- **Consistent interface**: Hook maintains same API for consumers
- **Better debugging**: Comprehensive logging for both GraphQL and REST

### User Experience
- **Instant feedback**: Cached data appears immediately
- **Smooth updates**: Background fetching doesn't block UI
- **Reliable service**: Fallback ensures data is always available

## Testing

See `usePipelineStatus.test.md` for manual testing procedures.

## Future Enhancements

1. **Optimistic Updates**: Update UI before server confirms changes
2. **Subscription Integration**: Real-time updates via GraphQL subscriptions
3. **Advanced Caching**: Implement custom cache policies for different data types
4. **Performance Monitoring**: Track GraphQL vs REST performance metrics
