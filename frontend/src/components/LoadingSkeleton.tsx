import { Box, Card, CardContent, Skeleton, Grid } from '@mui/material'

/**
 * Skeleton loading UI for the pipeline status page
 * Requirement 8.1: Display loading spinner or skeleton UI while data is loading
 */
export function CrawlerMetricsSkeleton() {
  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <Skeleton variant="circular" width={24} height={24} sx={{ mr: 1 }} />
          <Skeleton variant="text" width={200} height={32} />
        </Box>

        {/* Repository Crawler Section */}
        <Box sx={{ mb: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
            <Skeleton variant="circular" width={20} height={20} sx={{ mr: 1 }} />
            <Skeleton variant="text" width={150} height={24} />
            <Skeleton variant="rectangular" width={80} height={24} sx={{ ml: 'auto', borderRadius: 3 }} />
          </Box>

          <Grid container spacing={2}>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={12}>
              <Skeleton variant="rectangular" height={80} sx={{ borderRadius: 1 }} />
            </Grid>
          </Grid>
        </Box>

        <Skeleton variant="rectangular" height={1} sx={{ my: 2 }} />

        {/* User Crawler Section */}
        <Box sx={{ mb: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
            <Skeleton variant="circular" width={20} height={20} sx={{ mr: 1 }} />
            <Skeleton variant="text" width={150} height={24} />
            <Skeleton variant="rectangular" width={80} height={24} sx={{ ml: 'auto', borderRadius: 3 }} />
          </Box>

          <Grid container spacing={2}>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={6}>
              <Skeleton variant="text" width={120} height={16} />
              <Skeleton variant="text" width={100} height={32} />
            </Grid>
            <Grid item xs={12}>
              <Skeleton variant="rectangular" height={80} sx={{ borderRadius: 1 }} />
            </Grid>
          </Grid>
        </Box>
      </CardContent>
    </Card>
  )
}

export function ColdPathStatusSkeleton() {
  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <Skeleton variant="circular" width={24} height={24} sx={{ mr: 1 }} />
          <Skeleton variant="text" width={250} height={32} />
        </Box>

        <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, mb: 3 }}>
          <Box>
            <Skeleton variant="text" width={120} height={20} />
            <Skeleton variant="text" width={100} height={32} />
          </Box>
          <Box>
            <Skeleton variant="text" width={120} height={20} />
            <Skeleton variant="text" width={100} height={32} />
          </Box>
        </Box>

        <Box sx={{ mt: 2, display: 'flex', gap: 1 }}>
          <Skeleton variant="rectangular" width={180} height={24} sx={{ borderRadius: 3 }} />
        </Box>
      </CardContent>
    </Card>
  )
}

export function ErrorRateSkeleton() {
  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Box sx={{ display: 'flex', alignItems: 'center' }}>
            <Skeleton variant="circular" width={24} height={24} sx={{ mr: 1 }} />
            <Skeleton variant="text" width={150} height={24} />
          </Box>
          <Skeleton variant="rectangular" width={100} height={32} sx={{ borderRadius: 1 }} />
        </Box>
      </CardContent>
    </Card>
  )
}
