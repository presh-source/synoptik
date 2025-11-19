import { Card, CardContent, Typography, Box, Grid, Chip } from '@mui/material'
import { Speed as SpeedIcon, Storage as StorageIcon } from '@mui/icons-material'
import type { CrawlerMetrics } from '@/types'

interface CrawlerMetricsProps {
  repoCrawler?: CrawlerMetrics
  userCrawler?: CrawlerMetrics
}

export default function CrawlerMetricsCard({ repoCrawler, userCrawler }: CrawlerMetricsProps) {
  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num)
  }

  const formatRate = (rate: number, decimals: number = 2) => {
    return rate.toFixed(decimals)
  }

  const renderCrawlerSection = (
    title: string,
    icon: React.ReactNode,
    metrics?: CrawlerMetrics,
    color: string = 'primary.main'
  ) => {
    if (!metrics) {
      return (
        <Box sx={{ mb: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
            {icon}
            <Typography variant="subtitle1" fontWeight="bold" sx={{ ml: 1 }}>
              {title}
            </Typography>
          </Box>
          <Typography variant="body2" color="text.secondary">
            No data available
          </Typography>
        </Box>
      )
    }

    return (
      <Box sx={{ mb: 3 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          {icon}
          <Typography variant="subtitle1" fontWeight="bold" sx={{ ml: 1 }}>
            {title}
          </Typography>
          <Chip
            label={`${metrics.runCount} runs`}
            size="small"
            sx={{ ml: 'auto' }}
            color="default"
          />
        </Box>

        <Grid container spacing={2}>
          <Grid item xs={6}>
            <Typography variant="caption" color="text.secondary">
              Total Crawled
            </Typography>
            <Typography variant="h6" color={color}>
              {formatNumber(metrics.totalCrawled)}
            </Typography>
          </Grid>

          <Grid item xs={6}>
            <Typography variant="caption" color="text.secondary">
              API Requests
            </Typography>
            <Typography variant="h6" color={color}>
              {formatNumber(metrics.requestCount)}
            </Typography>
          </Grid>

          <Grid item xs={12}>
            <Box
              sx={{
                bgcolor: 'background.default',
                p: 1.5,
                borderRadius: 1,
                mt: 1,
              }}
            >
              <Typography variant="caption" color="text.secondary" display="block" gutterBottom>
                Crawl Rates
              </Typography>
              <Grid container spacing={1}>
                <Grid item xs={4}>
                  <Typography variant="body2" fontWeight="medium">
                    {formatRate(metrics.ratePerHour, 0)}/hr
                  </Typography>
                </Grid>
                <Grid item xs={4}>
                  <Typography variant="body2" fontWeight="medium">
                    {formatRate(metrics.ratePerMinute, 2)}/min
                  </Typography>
                </Grid>
                <Grid item xs={4}>
                  <Typography variant="body2" fontWeight="medium">
                    {formatRate(metrics.ratePerSecond, 4)}/sec
                  </Typography>
                </Grid>
              </Grid>
            </Box>
          </Grid>
        </Grid>
      </Box>
    )
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <SpeedIcon sx={{ mr: 1, color: 'info.main' }} />
          <Typography variant="h6">Crawler Performance Metrics</Typography>
        </Box>

        {renderCrawlerSection(
          'Repository Crawler',
          <StorageIcon sx={{ color: 'primary.main', fontSize: 20 }} />,
          repoCrawler,
          'primary.main'
        )}

        {renderCrawlerSection(
          'User Crawler',
          <StorageIcon sx={{ color: 'secondary.main', fontSize: 20 }} />,
          userCrawler,
          'secondary.main'
        )}

        <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
          Metrics based on last 1 hour of activity
        </Typography>
      </CardContent>
    </Card>
  )
}
