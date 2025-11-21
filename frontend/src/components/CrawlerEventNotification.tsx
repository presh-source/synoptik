import { useState, useEffect } from 'react'
import { Snackbar, Alert, AlertTitle, Box, Typography } from '@mui/material'
import { CheckCircle as SuccessIcon, Error as ErrorIcon } from '@mui/icons-material'
import { useOnCrawlerCompletedSubscription } from '@/graphql/generated/types'
import { logComponentEvent, logError } from '@/utils/logger'

/**
 * CrawlerEventNotification Component
 * 
 * Subscribes to crawler completion events via GraphQL subscription and displays
 * toast notifications when crawlers complete. Automatically refetches pipeline
 * status when events are received.
 * 
 * Features:
 * - Real-time WebSocket subscription to crawler events
 * - Toast notifications for successful and failed crawls
 * - Automatic pipeline status refetch on events
 * - Graceful error handling for subscription failures
 * - Auto-dismiss after 6 seconds
 * 
 * Requirements: 13.2, 13.3, 18.3, 18.4
 */

interface CrawlerEventNotificationProps {
  /**
   * Callback to refetch pipeline status when a crawler completes
   */
  onCrawlerCompleted?: () => void
  
  /**
   * Optional filter for crawler type ("repo" or "user")
   * If not provided, subscribes to all crawler events
   */
  crawlerType?: string
}

export default function CrawlerEventNotification({
  onCrawlerCompleted,
  crawlerType,
}: CrawlerEventNotificationProps) {
  const [open, setOpen] = useState(false)
  const [notificationData, setNotificationData] = useState<{
    crawlerType: string
    itemsFetched: number
    success: boolean
    errorMessage?: string | null
  } | null>(null)

  // Subscribe to crawler completion events
  // Requirement 13.2: Establish WebSocket connection for subscriptions
  const { error } = useOnCrawlerCompletedSubscription({
    variables: crawlerType ? { crawlerType } : {},
    // Requirement 18.4: Handle subscription errors gracefully
    onError: (error) => {
      logError('Subscription error for crawler events', error, {
        component: 'CrawlerEventNotification',
        action: 'subscribe',
        extra: {
          crawlerType,
        },
      })
    },
    // Requirement 13.3, 18.3: Receive events and update cache
    onData: ({ data: subscriptionData }) => {
      const event = subscriptionData.data?.onCrawlerCompleted
      
      if (event) {
        logComponentEvent('CrawlerEventNotification', 'crawler_completed', {
          extra: {
            crawlerType: event.crawlerType,
            itemsFetched: event.itemsFetched,
            success: event.success,
            startId: event.startId,
            endId: event.endId,
          },
        })

        // Store notification data
        setNotificationData({
          crawlerType: event.crawlerType,
          itemsFetched: event.itemsFetched,
          success: event.success,
          errorMessage: event.errorMessage,
        })

        // Show notification
        setOpen(true)

        // Refetch pipeline status to get updated metrics
        if (onCrawlerCompleted) {
          onCrawlerCompleted()
        }
      }
    },
  })

  // Log subscription errors
  useEffect(() => {
    if (error) {
      logError('Failed to maintain subscription to crawler events', error, {
        component: 'CrawlerEventNotification',
        action: 'subscription_error',
        extra: {
          crawlerType,
          errorMessage: error.message,
        },
      })
    }
  }, [error, crawlerType])

  const handleClose = (_event?: React.SyntheticEvent | Event, reason?: string) => {
    // Don't close on clickaway to ensure user sees the notification
    if (reason === 'clickaway') {
      return
    }
    setOpen(false)
  }

  if (!notificationData) {
    return null
  }

  const { crawlerType: type, itemsFetched, success, errorMessage } = notificationData

  return (
    <Snackbar
      open={open}
      autoHideDuration={6000}
      onClose={handleClose}
      anchorOrigin={{ vertical: 'top', horizontal: 'right' }}
    >
      <Alert
        onClose={handleClose}
        severity={success ? 'success' : 'error'}
        icon={success ? <SuccessIcon /> : <ErrorIcon />}
        sx={{ width: '100%', minWidth: 300 }}
      >
        <AlertTitle>
          {success
            ? `${type.charAt(0).toUpperCase() + type.slice(1)} Crawler Completed`
            : `${type.charAt(0).toUpperCase() + type.slice(1)} Crawler Failed`}
        </AlertTitle>
        <Box>
          {success ? (
            <Typography variant="body2">
              Successfully fetched {itemsFetched.toLocaleString()} items
            </Typography>
          ) : (
            <Typography variant="body2">
              {errorMessage || 'An error occurred during crawling'}
            </Typography>
          )}
        </Box>
      </Alert>
    </Snackbar>
  )
}
