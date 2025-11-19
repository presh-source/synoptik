import { Box, Typography, Grid, CircularProgress, Alert, Card, CardContent } from '@mui/material'
import { usePipelineStatus } from '@/hooks/usePipelineStatus'
import ColdPathStatusCard from '@/components/ColdPathStatus'
import ErrorRateIndicator from '@/components/ErrorRateIndicator'
import CrawlerMetricsCard from '@/components/CrawlerMetrics'

export default function PipelineStatusPage() {
  const { data, isLoading, error, isError } = usePipelineStatus(30000)

  if (isLoading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: 400 }}>
        <CircularProgress />
      </Box>
    )
  }

  if (isError) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Pipeline Status
        </Typography>
        <Alert severity="error">
          Failed to load pipeline status: {error instanceof Error ? error.message : 'Unknown error'}
        </Alert>
      </Box>
    )
  }

  if (!data) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Pipeline Status
        </Typography>
        <Alert severity="info">No pipeline data available</Alert>
      </Box>
    )
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Pipeline Status
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Real-time monitoring of the Cold Path data pipeline. Auto-refreshes every 30 seconds.
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12}>
          {data.errorRates ? (
            <ErrorRateIndicator errorRates={data.errorRates} />
          ) : (
            <Alert severity="warning">Error rate data not available.</Alert>
          )}
        </Grid>

        <Grid item xs={12} md={6}>
          {data.coldPath ? (
            <ColdPathStatusCard data={data.coldPath} />
          ) : (
            <Card>
              <CardContent>
                <Typography variant="h6">Cold Path Status</Typography>
                <Alert severity="info" sx={{ mt: 2 }}>
                  Data not available.
                </Alert>
              </CardContent>
            </Card>
          )}
        </Grid>

        <Grid item xs={12} md={6}>
          {data.coldPath ? (
            <CrawlerMetricsCard
              repoCrawler={data.coldPath.repoCrawler}
              userCrawler={data.coldPath.userCrawler}
            />
          ) : (
            <Card>
              <CardContent>
                <Typography variant="h6">Crawler Metrics</Typography>
                <Alert severity="info" sx={{ mt: 2 }}>
                  Data not available.
                </Alert>
              </CardContent>
            </Card>
          )}
        </Grid>
      </Grid>
    </Box>
  )
}
