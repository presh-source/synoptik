# Frontend Logging System

This directory contains utility functions for the frontend application, including a comprehensive logging system.

## Logger (`logger.ts`)

The logger provides centralized logging for the application with the following features:

### Features

1. **Console Logging**: All logs are written to the browser console in development and production
2. **Sentry Integration**: Errors and warnings are automatically sent to Sentry in production
3. **Breadcrumbs**: User actions and events are tracked as breadcrumbs for error context
4. **Categorization**: Logs are categorized (validation, api, user-action, component, navigation, performance)
5. **Context**: Each log can include component name, action, and extra data

### Usage

```typescript
import { logger, logApiError, logUserAction, logValidationError } from '@/utils/logger'

// Log an API error
logApiError('Failed to fetch data', error, {
  component: 'MyComponent',
  action: 'fetchData',
  extra: { userId: 123 }
})

// Log a user action
logUserAction('button_click', {
  component: 'MyButton',
  extra: { buttonId: 'submit' }
})

// Log a validation error
logValidationError('Invalid field value', {
  component: 'MyForm',
  extra: { field: 'email', value: 'invalid' }
})

// Log navigation
logNavigation('/dashboard', {
  extra: { from: '/home' }
})

// Log performance metrics
logPerformance('api_response_time', 234, 'ms', {
  extra: { endpoint: '/api/data' }
})
```

### Log Levels

- **debug**: Development-only logs, not sent to Sentry
- **info**: Informational messages, sent as breadcrumbs
- **warn**: Warnings, sent as breadcrumbs
- **error**: Errors, sent to Sentry with full context

### Categories

- **validation**: Data validation errors and warnings
- **api**: API request/response errors
- **user-action**: User interactions (clicks, form submissions, etc.)
- **component**: Component lifecycle events
- **navigation**: Route changes
- **performance**: Performance metrics

## Validation (`validation.ts`)

The validation module provides functions to validate and sanitize API responses:

- `validatePipelineStatusResponse()`: Validates the complete API response
- `validateColdPathStatus()`: Validates cold path data
- `validateCrawlerMetrics()`: Validates crawler metrics
- `validateErrorRates()`: Validates error rate data

All validation functions:
- Log warnings for missing fields
- Log errors for type mismatches
- Provide default values for invalid data
- Use the centralized logger for consistency

## Integration Points

### 1. API Client (`api/client.ts`)

The API client uses the logger to:
- Log all API requests (debug level)
- Log all API responses (debug level)
- Log API errors with full context (error level)

### 2. React Hooks (`hooks/usePipelineStatus.ts`)

The hooks use the logger to:
- Log successful data fetches (info level)
- Log fetch errors (error level)

### 3. Components (`pages/PipelineStatusPage.tsx`)

Components use the logger to:
- Log page views (user action)
- Log user interactions (user action)
- Log component lifecycle events (debug level)

### 4. App Router (`App.tsx`)

The router uses the logger to:
- Track navigation events
- Log route changes with context

## Sentry Configuration

Sentry is configured in `config/sentry.ts` with:

- **Environment Detection**: Only active in production
- **Performance Monitoring**: 10% sample rate
- **Session Replay**: Only on errors
- **Error Filtering**: Ignores browser extensions and common non-critical errors
- **Custom Tags**: Includes app name and component tags

### Environment Variables

Required environment variables:

- `VITE_SENTRY_DSN`: Sentry Data Source Name (DSN)
- `VITE_PROJECT_NAME`: Project name for tagging
- `VITE_APP_VERSION`: App version for release tracking

## Best Practices

1. **Always include context**: Provide component name and action when logging
2. **Use appropriate log levels**: Don't log errors as warnings
3. **Include extra data**: Add relevant data to help with debugging
4. **Log user actions**: Track important user interactions for analytics
5. **Don't log sensitive data**: Never log passwords, tokens, or PII
6. **Use categories**: Categorize logs for easier filtering

## Requirements Satisfied

This logging system satisfies the following requirements:

- **10.2**: Log validation errors and warnings to console
- **10.3**: Log API errors to console with full context
- **Production Errors**: Sentry integration for production error tracking
- **User Analytics**: User action logging for analytics
