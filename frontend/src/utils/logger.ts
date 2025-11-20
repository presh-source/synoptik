import { captureException, addBreadcrumb } from '@/config/sentry'

/**
 * Centralized logging utility for the application
 * Logs to console in all environments and to Sentry in production
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error'
export type LogCategory = 
  | 'validation' 
  | 'api' 
  | 'user-action' 
  | 'component' 
  | 'navigation'
  | 'performance'

interface LogContext {
  component?: string
  action?: string
  category?: LogCategory
  extra?: Record<string, unknown>
}

/**
 * Main logger class
 */
class Logger {
  private isDevelopment = import.meta.env.DEV

  /**
   * Log a debug message (console only, not sent to Sentry)
   */
  debug(message: string, context?: LogContext): void {
    if (this.isDevelopment) {
      console.debug(`[DEBUG] ${message}`, context)
    }
  }

  /**
   * Log an info message
   */
  info(message: string, context?: LogContext): void {
    console.info(`[INFO] ${message}`, context)
    
    // Add breadcrumb for Sentry
    addBreadcrumb(
      message,
      context?.category || 'info',
      'info',
      context?.extra
    )
  }

  /**
   * Log a warning message
   */
  warn(message: string, context?: LogContext): void {
    console.warn(`[WARN] ${message}`, context)
    
    // Add breadcrumb for Sentry
    addBreadcrumb(
      message,
      context?.category || 'warning',
      'warning',
      context?.extra
    )
  }

  /**
   * Log an error message
   */
  error(message: string, error?: Error | unknown, context?: LogContext): void {
    console.error(`[ERROR] ${message}`, error, context)
    
    // Send to Sentry in production
    if (error instanceof Error) {
      captureException(error, {
        component: context?.component,
        action: context?.action,
        extra: {
          message,
          ...context?.extra,
        },
      })
    } else {
      // If not an Error object, create one
      const err = new Error(message)
      captureException(err, {
        component: context?.component,
        action: context?.action,
        extra: {
          originalError: error,
          ...context?.extra,
        },
      })
    }
  }

  /**
   * Log a validation error
   */
  validationError(message: string, context?: Omit<LogContext, 'category'>): void {
    this.warn(message, { ...context, category: 'validation' })
  }

  /**
   * Log a validation warning
   */
  validationWarn(message: string, context?: Omit<LogContext, 'category'>): void {
    this.warn(message, { ...context, category: 'validation' })
  }

  /**
   * Log an API error
   */
  apiError(
    message: string,
    error: Error | unknown,
    context?: Omit<LogContext, 'category'>
  ): void {
    this.error(message, error, { ...context, category: 'api' })
  }

  /**
   * Log a user action for analytics
   */
  userAction(action: string, context?: Omit<LogContext, 'category' | 'action'>): void {
    this.info(`User action: ${action}`, {
      ...context,
      category: 'user-action',
      action,
    })
  }

  /**
   * Log a component lifecycle event
   */
  componentEvent(
    component: string,
    event: string,
    context?: Omit<LogContext, 'category' | 'component'>
  ): void {
    this.debug(`${component}: ${event}`, {
      ...context,
      category: 'component',
      component,
    })
  }

  /**
   * Log a navigation event
   */
  navigation(path: string, context?: Omit<LogContext, 'category'>): void {
    this.info(`Navigation to: ${path}`, {
      ...context,
      category: 'navigation',
      extra: {
        path,
        ...context?.extra,
      },
    })
  }

  /**
   * Log a performance metric
   */
  performance(
    metric: string,
    value: number,
    unit: string = 'ms',
    context?: Omit<LogContext, 'category'>
  ): void {
    this.info(`Performance: ${metric} = ${value}${unit}`, {
      ...context,
      category: 'performance',
      extra: {
        metric,
        value,
        unit,
        ...context?.extra,
      },
    })
  }
}

// Export singleton instance
export const logger = new Logger()

// Export convenience functions
export const logDebug = logger.debug.bind(logger)
export const logInfo = logger.info.bind(logger)
export const logWarn = logger.warn.bind(logger)
export const logError = logger.error.bind(logger)
export const logValidationError = logger.validationError.bind(logger)
export const logValidationWarn = logger.validationWarn.bind(logger)
export const logApiError = logger.apiError.bind(logger)
export const logUserAction = logger.userAction.bind(logger)
export const logComponentEvent = logger.componentEvent.bind(logger)
export const logNavigation = logger.navigation.bind(logger)
export const logPerformance = logger.performance.bind(logger)
