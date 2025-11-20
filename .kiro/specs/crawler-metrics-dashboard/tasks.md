# Implementation Plan

- [x] 1. Update backend Lambda function to return exact payload structure
  - Modify `pipeline_status.py` to ensure response matches specified format
  - Ensure all field names use camelCase (not snake_case)
  - Verify numeric types (integers vs floats) are correct
  - Add proper error handling for missing data
  - _Requirements: 1.4, 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ]* 1.1 Write property test for API response structure
  - **Property 2: API response contains required structure**
  - **Validates: Requirements 7.1**

- [ ]* 1.2 Write property test for coldPath object structure
  - **Property 3: ColdPath object contains crawler objects**
  - **Validates: Requirements 7.2**

- [ ]* 1.3 Write property test for crawler object completeness
  - **Property 4: Crawler objects are complete**
  - **Validates: Requirements 7.3**

- [ ]* 1.4 Write property test for numeric type correctness
  - **Property 15: Numeric types are correct**
  - **Validates: Requirements 7.4**

- [ ]* 1.5 Write property test for camelCase field names
  - **Property 16: Field names are camelCase**
  - **Validates: Requirements 7.5**

- [x] 2. Update TypeScript interfaces to match payload structure
  - Define `CrawlerMetrics` interface with all 8 fields
  - Define `ColdPathStatus` interface
  - Define `ErrorRates` interface
  - Define `PipelineStatusResponse` interface
  - Ensure interfaces match backend response exactly
  - _Requirements: 7.1, 7.2, 7.3, 10.5_

- [x] 3. Implement response validation in frontend
  - Create validation function to check required fields
  - Add default values for missing fields
  - Add type coercion for incorrect types
  - Log warnings/errors for validation failures
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ]* 3.1 Write property test for response validation
  - **Property 18: Response validation checks required fields**
  - **Validates: Requirements 10.1**

- [ ]* 3.2 Write property test for missing field defaults
  - **Property 19: Missing fields use defaults**
  - **Validates: Requirements 10.2**

- [ ]* 3.3 Write property test for type coercion
  - **Property 20: Type coercion for wrong types**
  - **Validates: Requirements 10.3**

- [x] 4. Implement number formatting utilities
  - Create `formatLargeNumber()` function with thousand separators
  - Create `formatRate()` function with configurable decimal precision
  - Create `formatInteger()` function without decimals
  - Create `formatPercentage()` function with 1 decimal place
  - _Requirements: 2.4, 3.4, 4.3, 5.2_

- [ ]* 4.1 Write property test for large number formatting
  - **Property 5: Large numbers are formatted with separators**
  - **Validates: Requirements 2.4**

- [ ]* 4.2 Write property test for rate decimal precision
  - **Property 6: Rates have correct decimal precision**
  - **Validates: Requirements 3.4**

- [ ]* 4.3 Write property test for integer formatting
  - **Property 7: Counts are formatted as integers**
  - **Validates: Requirements 4.3**

- [ ]* 4.4 Write property test for error rate formatting
  - **Property 8: Error rate formatted with one decimal**
  - **Validates: Requirements 5.2**

- [x] 5. Implement timestamp formatting utilities
  - Create `formatTimestamp()` function for human-readable display
  - Add timezone conversion to user's local time
  - Ensure both date and time are included
  - Create `isStale()` function to check if data is > 5 minutes old
  - _Requirements: 6.1, 6.2, 6.3, 6.5_

- [ ]* 5.1 Write property test for timezone conversion
  - **Property 12: Timestamp timezone conversion**
  - **Validates: Requirements 6.2**

- [ ]* 5.2 Write property test for stale data detection
  - **Property 13: Stale data warning**
  - **Validates: Requirements 6.3**

- [ ]* 5.3 Write property test for timestamp format
  - **Property 14: Timestamp includes date and time**
  - **Validates: Requirements 6.5**

- [x] 6. Implement error rate indicator component
  - Create `ErrorRateIndicator` component
  - Show success indicator (green) for < 5%
  - Show warning indicator (yellow) for 5-10%
  - Show error indicator (red) for > 10%
  - Display percentage with 1 decimal place
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ]* 6.1 Write property test for warning indicator
  - **Property 9: Error rate warning indicator**
  - **Validates: Requirements 5.3**

- [ ]* 6.2 Write property test for error indicator
  - **Property 10: Error rate error indicator**
  - **Validates: Requirements 5.4**

- [ ]* 6.3 Write property test for success indicator
  - **Property 11: Error rate success indicator**
  - **Validates: Requirements 5.5**

- [x] 7. Update CrawlerMetricsCard component
  - Accept `repoCrawler` and `userCrawler` props
  - Display all 8 fields for each crawler type
  - Use formatting utilities for numbers and rates
  - Add visual distinction between repo and user sections
  - Add icons/labels for crawler types
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2, 3.3, 4.1, 4.2, 9.1, 9.2_

- [ ]* 7.1 Write property test for all fields displayed
  - **Property 1: All required crawler fields are displayed**
  - **Validates: Requirements 1.2**

- [x] 8. Update ColdPathStatusCard component
  - Display lastProcessedId and totalProcessed
  - Display updatedAt timestamp with formatting
  - Show stale data warning if needed
  - Use number formatting for large values
  - _Requirements: 2.1, 2.2, 2.4, 6.1, 6.2, 6.3, 6.5_

- [x] 9. Update usePipelineStatus hook
  - Ensure 30-second polling interval
  - Add response validation before returning data
  - Handle loading states
  - Handle error states
  - Implement automatic error recovery
  - _Requirements: 1.3, 8.1, 8.2, 8.5_

- [ ]* 9.1 Write property test for error recovery
  - **Property 17: Error recovery updates UI**
  - **Validates: Requirements 8.5**

- [x] 10. Implement loading and error states
  - Add loading spinner/skeleton UI
  - Add error message display with retry button
  - Add empty state for unavailable data
  - Add network error handling
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 11. Update PipelineStatusPage
  - Integrate updated components
  - Add error rate indicator
  - Ensure responsive layout (mobile/desktop)
  - Add auto-refresh indicator
  - _Requirements: 1.1, 1.3, 5.1, 9.4, 9.5_

- [x] 12. Add responsive styling
  - Stack crawler sections vertically on mobile
  - Display side-by-side on desktop
  - Ensure readability on all screen sizes
  - Test on various devices
  - _Requirements: 9.4, 9.5_

- [x] 13. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Update backend error handling
  - Add try-catch blocks for CloudWatch queries
  - Add try-catch blocks for DynamoDB queries
  - Return zero values on failures
  - Log errors to Sentry with context
  - _Requirements: 1.5, 4.5_

- [x] 15. Add backend logging
  - Add structured logging for all operations
  - Log CloudWatch query parameters
  - Log DynamoDB query results
  - Log rate calculations
  - _Requirements: 10.2, 10.3_

- [x] 16. Add frontend logging
  - Log validation errors to console
  - Log API errors to console
  - Add Sentry integration for production errors
  - Log user actions for analytics
  - _Requirements: 10.2, 10.3_

- [x] 17. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 18. Manual testing
  - Test dashboard loads and displays metrics
  - Verify both repo and user crawler sections visible
  - Verify all 8 fields displayed for each crawler
  - Verify numbers formatted with thousand separators
  - Verify rates have correct decimal precision
  - Verify error rate indicator shows correct color
  - Verify timestamp displays in local timezone
  - Verify auto-refresh works every 30 seconds
  - Verify loading state shows spinner
  - Verify error state shows error message
  - Test mobile layout stacks vertically
  - Test desktop layout shows side-by-side
