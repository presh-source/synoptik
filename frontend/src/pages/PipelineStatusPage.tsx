import { Box, Typography, Grid, Chip } from '@mui/material'
import { Refresh as RefreshIcon } from '@mui/icons-material'
import { useEffect } from 'react'
import { usePipelineStatus } from '@/hooks/usePipelineStatus'
import ColdPathStatusCard from '@/components/ColdPathStatus'
import ErrorRateIndicator from '@/components/ErrorRateIndicator'
import CrawlerMetricsCard from '@/components/CrawlerMetrics'
import { CrawlerMetricsSkeleton, ColdPathStatusSkeleton, ErrorRateSkeleton } from '@/components/LoadingSkeleton'
import ErrorDisplay, { InlineErrorDisplay } from '@/components/ErrorDisplay'
import EmptyState from '@/components/EmptyState'
import CrawlerEventNotification from '@/components/CrawlerEventNotification'
import { logUserAction, logComponentEvent } from '@/utils/logger'

export default function PipelineStatusPage() {
  const { data, isLoading, error, isError, refetch } = usePipelineStatus(30000)

  // Log page view on mount
  useEffect(() => {
    logUserAction('view_pipeline_status_page', {
      component: 'PipelineStatusPage',
    })
  }, [])

  // Log when data is successfully loaded
  useEffect(() => {
    if (data && !isLoading) {
      logComponentEvent('PipelineStatusPage', 'data_loaded', {
        extra: {
          hasData: !!data,
          hasError: isError,
        },
      })
    }
  }, [data, isLoading, isError])

  // Handle manual retry with logging
  const handleRetry = () => {
    logUserAction('retry_pipeline_status', {
      component: 'PipelineStatusPage',
      extra: { hasError: isError },
    })
    refetch()
  }

  // Requirement 8.1: Display loading spinner or skeleton UI
  if (isLoading && !data) {
    return (
      <Box>
        <Typography 
          variant="h4" 
          gutterBottom
          sx={{ fontSize: { xs: '1.75rem', sm: '2.125rem' } }}
        >
          Pipeline Status
        </Typography>
        <Typography 
          variant="body2" 
          color="text.secondary" 
          sx={{ 
            mb: 3,
            fontSize: { xs: '0.8rem', sm: '0.875rem' }
          }}
        >
          Real-time monitoring of the Cold Path data pipeline. Auto-refreshes every 30 seconds.
        </Typography>

        <Grid container spacing={3}>
          <Grid item xs={12}>
            <ErrorRateSkeleton />
          </Grid>
          <Grid item xs={12} md={6}>
            <ColdPathStatusSkeleton />
          </Grid>
          <Grid item xs={12} md={6}>
            <CrawlerMetricsSkeleton />
          </Grid>
        </Grid>
      </Box>
    )
  }

  // Requirement 8.2, 8.4: Display error message with retry button and network error handling
  if (isError && !data) {
    return (
      <Box>
        <Typography 
          variant="h4" 
          gutterBottom
          sx={{ fontSize: { xs: '1.75rem', sm: '2.125rem' } }}
        >
          Pipeline Status
        </Typography>
        <Typography 
          variant="body2" 
          color="text.secondary" 
          sx={{ 
            mb: 3,
            fontSize: { xs: '0.8rem', sm: '0.875rem' }
          }}
        >
          Real-time monitoring of the Cold Path data pipeline. Auto-refreshes every 30 seconds.
        </Typography>

        <Grid container spacing={3}>
          <Grid item xs={12}>
            <ErrorDisplay 
              error={error} 
              onRetry={handleRetry}
              title="Failed to Load Pipeline Status"
            />
          </Grid>
        </Grid>
      </Box>
    )
  }

  // Requirement 8.3: Show placeholder values and indicate data is not available
  if (!data) {
    return (
      <Box>
        <Typography 
          variant="h4" 
          gutterBottom
          sx={{ fontSize: { xs: '1.75rem', sm: '2.125rem' } }}
        >
          Pipeline Status
        </Typography>
        <Typography 
          variant="body2" 
          color="text.secondary" 
          sx={{ 
            mb: 3,
            fontSize: { xs: '0.8rem', sm: '0.875rem' }
          }}
        >
          Real-time monitoring of the Cold Path data pipeline. Auto-refreshes every 30 seconds.
        </Typography>

        <Grid container spacing={3}>
          <Grid item xs={12}>
            <EmptyState 
              title="No Pipeline Data Available"
              message="Pipeline status data is currently unavailable. The system will automatically retry."
            />
          </Grid>
        </Grid>
      </Box>
    )
  }

  // Main view with data
  return (
    <Box>
      {/* Crawler event notification subscription - Requirements 13.2, 13.3, 18.3, 18.4 */}
      <CrawlerEventNotification onCrawlerCompleted={() => refetch()} />
      
      <Box 
        sx={{ 
          display: 'flex', 
          alignItems: { xs: 'flex-start', sm: 'center' }, 
          justifyContent: 'space-between', 
          mb: 1,
          flexDirection: { xs: 'column', sm: 'row' },
          gap: { xs: 1, sm: 0 }
        }}
      >
        <Typography 
          variant="h4"
          sx={{ fontSize: { xs: '1.75rem', sm: '2.125rem' } }}
        >
          Pipeline Status
        </Typography>
        {/* Auto-refresh indicator - Requirement 1.3 */}
        <Chip
          icon={<RefreshIcon />}
          label="Auto-refresh: 30s"
          size="small"
          color="primary"
          variant="outlined"
        />
      </Box>
      <Typography 
        variant="body2" 
        color="text.secondary" 
        sx={{ 
          mb: 3,
          fontSize: { xs: '0.8rem', sm: '0.875rem' }
        }}
      >
        Real-time monitoring of the Cold Path data pipeline. Auto-refreshes every 30 seconds.
      </Typography>

      {/* Show inline error if there's an error but we have cached data - Requirement 8.5 */}
      {isError && data && (
        <Box sx={{ mb: 2 }}>
          <InlineErrorDisplay error={error} onRetry={handleRetry} />
        </Box>
      )}

      <Grid container spacing={3}>
        <Grid item xs={12}>
          {data.errorRates ? (
            <ErrorRateIndicator errorRates={data.errorRates} />
          ) : (
            <EmptyState 
              title="Error Rate Data Unavailable"
              message="Error rate metrics are currently unavailable."
            />
          )}
        </Grid>

        <Grid item xs={12} md={6}>
          {data.coldPath ? (
            <ColdPathStatusCard data={data.coldPath} />
          ) : (
            <EmptyState 
              title="Cold Path Status Unavailable"
              message="Cold Path status data is currently unavailable."
            />
          )}
        </Grid>

        <Grid item xs={12} md={6}>
          {data.coldPath ? (
            <CrawlerMetricsCard
              repoCrawler={data.coldPath.repoCrawler}
              userCrawler={data.coldPath.userCrawler}
            />
          ) : (
            <EmptyState 
              title="Crawler Metrics Unavailable"
              message="Crawler performance metrics are currently unavailable."
            />
          )}
        </Grid>
      </Grid>
    </Box>
  )
}
