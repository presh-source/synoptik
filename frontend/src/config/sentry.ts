import * as Sentry from "@sentry/react";
import { BrowserTracing } from "@sentry/tracing";

export const initSentry = () => {
  // Only initialize Sentry in production
  if (import.meta.env.PROD && import.meta.env.VITE_SENTRY_DSN) {
    Sentry.init({
      dsn: import.meta.env.VITE_SENTRY_DSN,
      
      integrations: [
        new BrowserTracing({
          // Set sampling rate for performance monitoring
          tracePropagationTargets: ["localhost", /^https:\/\/yourserver\.io\/api/],
        }),
        new Sentry.Replay({
          // Mask all text content for privacy
          maskAllText: true,
          blockAllMedia: true,
        }),
      ],
      
      // Performance Monitoring
      tracesSampleRate: 0.1, // Capture 10% of transactions for performance monitoring
      
      // Session Replay
      replaysSessionSampleRate: 0, // Don't record normal sessions
      replaysOnErrorSampleRate: 1.0, // Record 100% of sessions with errors
      
      // Environment
      environment: import.meta.env.MODE,
      
      // Release tracking
      release: `${import.meta.env.VITE_PROJECT_NAME}-dashboard@${import.meta.env.VITE_APP_VERSION || '1.0.0'}`,
      
      // Ignore common non-critical errors
      ignoreErrors: [
        // Browser extensions
        'top.GLOBALS',
        'chrome-extension://',
        'moz-extension://',
        // Network errors
        'NetworkError',
        'Network request failed',
        // ResizeObserver errors (common and harmless)
        'ResizeObserver loop limit exceeded',
      ],
      
      // Filter events before sending
      beforeSend(event) {
        // Don't send events in development
        if (import.meta.env.DEV) {
          console.log('Sentry event (dev mode):', event);
          return null;
        }
        
        // Add custom filtering logic here
        return event;
      },
      
      // Add custom tags
      initialScope: {
        tags: {
          'app.name': `${import.meta.env.VITE_PROJECT_NAME}-dashboard`,
          'app.component': 'frontend',
        },
      },
    });
    
    console.log('Sentry initialized');
  } else {
    console.log('Sentry not initialized (dev mode or missing DSN)');
  }
};

// Helper function to capture exceptions with context
export const captureException = (
  error: Error,
  context?: {
    component?: string;
    action?: string;
    extra?: Record<string, unknown>;
  }
) => {
  Sentry.captureException(error, {
    tags: {
      component: context?.component,
      action: context?.action,
    },
    extra: context?.extra,
  });
};

// Helper function to add breadcrumbs
export const addBreadcrumb = (
  message: string,
  category: string = 'user-action',
  level: Sentry.SeverityLevel = 'info',
  data?: Record<string, unknown>
) => {
  Sentry.addBreadcrumb({
    message,
    category,
    level,
    data,
  });
};

// Helper function to set user context
export const setUser = (user: {
  id?: string;
  email?: string;
  username?: string;
}) => {
  Sentry.setUser(user);
};

// Helper function to clear user context
export const clearUser = () => {
  Sentry.setUser(null);
};
