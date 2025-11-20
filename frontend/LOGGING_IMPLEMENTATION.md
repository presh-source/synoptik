# Frontend Logging Implementation

## Overview

This document describes the comprehensive logging system implemented for the crawler metrics dashboard frontend application.

## Task Requirements

✅ **Log validation errors to console**
✅ **Log API errors to console**
✅ **Add Sentry integration for production errors**
✅ **Log user actions for analytics**

## Implementation Details

### 1. Centralized Logger (`src/utils/logger.ts`)

Created a comprehensive logging utility that provides:

- **Multiple log levels**: debug, info, warn, error
- **Categorization**: validation, api, user-action, component, navigation, performance
- **Sentry integration**: Automatic error reporting in production
- **Breadcrumbs**: Context tracking for error debugging
- **Type-safe API**: TypeScript interfaces for all logging functions

**Key Functions:**
- `logDebug()` - Development-only logging
- `logInfo()` - Informational messages
- `logWarn()` - Warning messages
- `logError()` - Error messages with Sentry reporting
- `logValidationError()` - Validation-specific errors
- `logValidationWarn()` - Validation-specific warnings
- `logApiError()` - API-specific errors
- `logUserAction()` - User interaction tracking
- `logComponentEvent()` - Component lifecycle events
- `logNavigation()` - Route change tracking
- `logPerformance()` - Performance metric tracking

### 2. Enhanced Validation Logging (`src/utils/validation.ts`)

Updated all validation functions to use the centralized logger:

- **Missing fields**: Log warnings with context
- **Type mismatches**: Log errors with original and coerced values
- **Invalid structures**: Log errors with received type information
- **Default values**: Log when defaults are used

**Functions Updated:**
- `validatePipelineStatusResponse()`
- `validateColdPathStatus()`
- `validateCrawlerMetrics()`
- `validateErrorRates()`
- `coerceToNumber()`
- `coerceToString()`

### 3. Enhanced API Client Logging (`src/api/client.ts`)

Added comprehensive logging to the Axios client:

**Request Interceptor:**
- Logs all outgoing requests (debug level)
- Includes method, URL, and configuration

**Response Interceptor:**
- Logs successful responses (debug level)
- Includes status, URL, and response size
- Logs errors with full context (error level)
- Distinguishes network errors from API errors
- Includes status code, error message, and response data

### 4. Enhanced Hook Logging (`src/hooks/usePipelineStatus.ts`)

Added logging to the pipeline status hook:

- **Success**: Logs successful data fetches with key metrics
- **Errors**: Logs fetch failures with full error context
- **Context**: Includes component name and action

### 5. User Action Logging (`src/pages/PipelineStatusPage.tsx`)

Added user action tracking:

- **Page views**: Logs when user views the page
- **Data loaded**: Logs when data is successfully loaded
- **Retry actions**: Logs when user clicks retry button
- **Context**: Includes component name and relevant data

### 6. Navigation Logging (`src/App.tsx`)

Added navigation tracking:

- **Route changes**: Logs all navigation events
- **Context**: Includes pathname, search params, and hash
- **Automatic**: Tracks all route changes automatically

### 7. Sentry Initialization (`src/main.tsx`)

Initialized Sentry on application startup:

- **Production only**: Only active in production environment
- **Automatic**: Initializes before React renders
- **Configuration**: Uses existing Sentry config from `config/sentry.ts`

## Logging Flow

```
User Action
    ↓
Component logs user action → Sentry Breadcrumb
    ↓
API Request
    ↓
API Client logs request → Console (debug)
    ↓
API Response/Error
    ↓
API Client logs response → Console (debug/error) + Sentry (if error)
    ↓
Validation
    ↓
Validation logs issues → Console (warn/error) + Sentry Breadcrumb
    ↓
Component renders
    ↓
Component logs lifecycle → Console (debug)
```

## Console Output Examples

### Development Mode

```
[DEBUG] API Request: GET /pipeline-status
[INFO] Pipeline status fetched successfully
[WARN] Missing field: coldPath.repoCrawler.ratePerHour, using default value 0
[ERROR] Type mismatch for coldPath.userCrawler.totalCrawled: expected number, got string, coerced to 12345
```

### Production Mode

```
[INFO] Pipeline status fetched successfully
[WARN] Missing field: coldPath.repoCrawler.ratePerHour, using default value 0
[ERROR] API Error: GET /pipeline-status - 500
```

(Errors are also sent to Sentry with full context)

## Sentry Integration

### What Gets Sent to Sentry

1. **Errors**: All errors logged via `logError()` or `logApiError()`
2. **Breadcrumbs**: All info and warn logs as context
3. **Context**: Component name, action, and extra data
4. **User Actions**: Tracked as breadcrumbs for error context

### What Doesn't Get Sent

1. **Debug logs**: Development-only, never sent
2. **Development mode**: Sentry is disabled in development
3. **Filtered errors**: Browser extensions, network errors (configurable)

## Environment Variables

Required for Sentry:

```env
VITE_SENTRY_DSN=https://your-dsn@sentry.io/project-id
VITE_PROJECT_NAME=your-project-name
VITE_APP_VERSION=1.0.0
```

## Testing

### Manual Testing

1. **Console Logging**: Open browser console and verify logs appear
2. **Validation Errors**: Send invalid API response and check console
3. **API Errors**: Disconnect network and check error logging
4. **User Actions**: Click buttons and check action logs
5. **Navigation**: Navigate between pages and check navigation logs

### Sentry Testing

1. Set `VITE_SENTRY_DSN` in `.env.local`
2. Build for production: `npm run build`
3. Serve production build: `npm run preview`
4. Trigger an error (e.g., disconnect network)
5. Check Sentry dashboard for error report

## Benefits

1. **Debugging**: Comprehensive logs make debugging easier
2. **Monitoring**: Sentry provides real-time error monitoring
3. **Analytics**: User action logs provide usage insights
4. **Context**: Breadcrumbs provide context for errors
5. **Performance**: Performance logs help identify bottlenecks
6. **Consistency**: Centralized logger ensures consistent logging

## Requirements Satisfied

- ✅ **Requirement 10.2**: Log validation errors and warnings to console
- ✅ **Requirement 10.3**: Log API errors to console with full context
- ✅ **Production Monitoring**: Sentry integration for production errors
- ✅ **User Analytics**: User action logging for analytics and insights

## Files Modified

1. `src/utils/logger.ts` - New centralized logger
2. `src/utils/validation.ts` - Enhanced with logger
3. `src/api/client.ts` - Enhanced with logger
4. `src/hooks/usePipelineStatus.ts` - Enhanced with logger
5. `src/pages/PipelineStatusPage.tsx` - Added user action logging
6. `src/App.tsx` - Added navigation logging
7. `src/main.tsx` - Added Sentry initialization

## Documentation

- `src/utils/README.md` - Comprehensive logging documentation
- `frontend/LOGGING_IMPLEMENTATION.md` - This file
