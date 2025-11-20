import { Box, Alert, Button, Typography, Card, CardContent } from '@mui/material'
import { 
  Refresh as RefreshIcon, 
  ErrorOutline as ErrorIcon,
  WifiOff as WifiOffIcon 
} from '@mui/icons-material'
import { AxiosError } from 'axios'

interface ErrorDisplayProps {
  error: Error | unknown
  onRetry?: () => void
  title?: string
}

/**
 * Error display component with retry functionality
 * Requirements: 8.2, 8.4
 * - 8.2: Display error message with details
 * - 8.4: Display connection error message for network errors
 */
export default function ErrorDisplay({ error, onRetry, title = 'Error Loading Data' }: ErrorDisplayProps) {
  // Determine error type and message
  const isNetworkError = error instanceof AxiosError && 
    (error.code === 'ECONNABORTED' || 
     error.code === 'ERR_NETWORK' || 
     error.message.includes('Network Error') ||
     !error.response)
  
  const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred'
  
  const severity = isNetworkError ? 'warning' : 'error'
  const icon = isNetworkError ? <WifiOffIcon /> : <ErrorIcon />
  const displayTitle = isNetworkError ? 'Connection Error' : title

  return (
    <Card>
      <CardContent>
        <Alert 
          severity={severity}
          icon={icon}
          sx={{ mb: 2 }}
        >
          <Typography variant="subtitle2" fontWeight="bold">
            {displayTitle}
          </Typography>
          <Typography variant="body2" sx={{ mt: 0.5 }}>
            {isNetworkError 
              ? 'Unable to connect to the server. Please check your network connection.'
              : errorMessage
            }
          </Typography>
        </Alert>

        {onRetry && (
          <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2 }}>
            <Button
              variant="contained"
              startIcon={<RefreshIcon />}
              onClick={onRetry}
              size="medium"
            >
              Retry
            </Button>
          </Box>
        )}

        {isNetworkError && (
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 2, textAlign: 'center' }}>
            The dashboard will automatically retry when the connection is restored.
          </Typography>
        )}
      </CardContent>
    </Card>
  )
}

/**
 * Inline error display for smaller error states
 */
export function InlineErrorDisplay({ error, onRetry }: ErrorDisplayProps) {
  const isNetworkError = error instanceof AxiosError && 
    (error.code === 'ECONNABORTED' || 
     error.code === 'ERR_NETWORK' || 
     error.message.includes('Network Error') ||
     !error.response)
  
  const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred'

  return (
    <Alert 
      severity={isNetworkError ? 'warning' : 'error'}
      action={
        onRetry && (
          <Button color="inherit" size="small" onClick={onRetry}>
            Retry
          </Button>
        )
      }
    >
      {isNetworkError 
        ? 'Connection error. Unable to load data.'
        : errorMessage
      }
    </Alert>
  )
}
