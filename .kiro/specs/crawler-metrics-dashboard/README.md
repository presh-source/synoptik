# Crawler Metrics Dashboard - Feature Spec

## Overview

This spec enhances the observability dashboard to display comprehensive crawler metrics for both repository and user crawlers in the Cold Path pipeline, matching the exact payload structure specified.

## Payload Structure

```json
{
  "coldPath": {
    "repoCrawler": {
      "lastProcessedId": 71280462,
      "totalProcessed": 34538600,
      "totalCrawled": 0,
      "ratePerHour": 0.0,
      "ratePerMinute": 0.0,
      "ratePerSecond": 0.0,
      "requestCount": 0,
      "runCount": 0
    },
    "userCrawler": {
      "lastProcessedId": 71280462,
      "totalProcessed": 34538600,
      "totalCrawled": 0,
      "ratePerHour": 0.0,
      "ratePerMinute": 0.0,
      "ratePerSecond": 0.0,
      "requestCount": 0,
      "runCount": 0
    },
    "updatedAt": "2025-11-20T04:41:36.796187+00:00"
  },
  "errorRates": {
    "coldPath": 0.1
  }
}
```

## Documents

- **[requirements.md](./requirements.md)**: 10 user stories with 50 acceptance criteria
- **[design.md](./design.md)**: Architecture, components, data models, 20 correctness properties
- **[tasks.md](./tasks.md)**: 18 implementation tasks with property-based tests

## Key Features

### Backend
- Lambda function returns exact payload structure
- All field names in camelCase
- Correct numeric types (int vs float)
- Error handling with zero values fallback
- Structured logging to Sentry

### Frontend
- TypeScript interfaces matching payload exactly
- Response validation with defaults
- Number formatting (thousand separators, decimal precision)
- Timestamp formatting (local timezone, human-readable)
- Error rate indicators (success/warning/error)
- Auto-refresh every 30 seconds
- Loading and error states
- Responsive layout (mobile/desktop)

## Implementation Approach

### Phase 1: Core Functionality (Required Tasks)
1. Backend payload structure updates
2. TypeScript interfaces
3. Response validation
4. Formatting utilities
5. UI component updates
6. Error handling
7. Responsive styling

### Phase 2: Testing (Optional Tasks)
1. 15 property-based tests
2. Manual testing checklist

## Testing Strategy

### Property-Based Testing
- **Backend**: Hypothesis (Python)
- **Frontend**: fast-check (TypeScript)
- **Coverage**: 20 correctness properties

### Unit Testing
- Lambda functions with mocked AWS services
- React components with mocked API responses
- Formatting utilities with edge cases

### Integration Testing
- End-to-end flow from Lambda to UI
- Auto-refresh behavior
- Error recovery

## Success Criteria

✅ Dashboard displays exact payload structure
✅ All 8 fields shown for each crawler type
✅ Numbers formatted with thousand separators
✅ Rates have correct decimal precision
✅ Error rate indicator shows correct color
✅ Timestamp in local timezone
✅ Auto-refresh every 30 seconds
✅ Graceful error handling
✅ Responsive on mobile and desktop

## Next Steps

To start implementation:

1. Open `tasks.md` in the Kiro IDE
2. Click "Start task" next to Task 1
3. Follow the implementation plan sequentially
4. Run tests after each checkpoint

## Questions?

If you have questions about the requirements, design, or implementation approach, please ask before starting implementation.
