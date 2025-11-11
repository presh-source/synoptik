import { useState } from 'react'
import { Box, Typography, Grid, CircularProgress, Alert } from '@mui/material'
import { useRealTimeMetrics } from '@/hooks/useRealTimeMetrics'
import TrendingRepositories from '@/components/TrendingRepositories'
import LanguageDistribution from '@/components/LanguageDistribution'
import RepositoryCreationTrends from '@/components/RepositoryCreationTrends'
import MetricsFilters from '@/components/MetricsFilters'
import type { MetricsFilters as MetricsFiltersType } from '@/types'

export default function RealTimeMetricsPage() {
  const [filters, setFilters] = useState<MetricsFiltersType>({})
  const { data, isLoading, error, isError } = useRealTimeMetrics(filters, 60000)

  const handleApplyFilters = (newFilters: MetricsFiltersType) => {
    setFilters(newFilters)
  }

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
          Real-Time Metrics
        </Typography>
        <Alert severity="error">
          Failed to load metrics: {error instanceof Error ? error.message : 'Unknown error'}
        </Alert>
      </Box>
    )
  }

  if (!data) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Real-Time Metrics
        </Typography>
        <Alert severity="info">No metrics data available</Alert>
      </Box>
    )
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Real-Time Metrics
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Live GitHub ecosystem metrics. Auto-refreshes every 60 seconds.
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12}>
          <MetricsFilters onApplyFilters={handleApplyFilters} />
        </Grid>

        <Grid item xs={12} lg={6}>
          <TrendingRepositories repositories={data.trendingRepositories} />
        </Grid>

        <Grid item xs={12} lg={6}>
          <Grid container spacing={3}>
            <Grid item xs={12}>
              <LanguageDistribution data={data.languageDistribution} />
            </Grid>
            <Grid item xs={12}>
              <RepositoryCreationTrends data={data.creationTrends} />
            </Grid>
          </Grid>
        </Grid>
      </Grid>
    </Box>
  )
}
