import { Card, CardContent, Typography, Box, Grid, Chip, Divider } from '@mui/material'
import { 
  Speed as SpeedIcon, 
  FolderSpecial as RepoIcon,
  Person as UserIcon 
} from '@mui/icons-material'
import type { ReactNode } from 'react'
import type { CrawlerMetrics } from '@/types'
import { formatLargeNumber, formatRate, formatInteger } from '@/utils/formatting'

interface CrawlerMetricsProps {
  repoCrawler?: CrawlerMetrics
  userCrawler?: CrawlerMetrics
}

export default function CrawlerMetricsCard({ repoCrawler, userCrawler }: CrawlerMetricsProps) {
  const renderCrawlerSection = (
    title: string,
    icon: ReactNode,
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
        {/* Header with icon, title, and run count */}
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          {icon}
          <Typography variant="subtitle1" fontWeight="bold" sx={{ ml: 1 }}>
            {title}
          </Typography>
          <Chip
            label={`${formatInteger(metrics.runCount)} runs`}
            size="small"
            sx={{ ml: 'auto' }}
            color="default"
          />
        </Box>

        {/* All 8 required fields displayed in a grid */}
        <Grid container spacing={2}>
          {/* Row 1: Last Processed ID and Total Processed */}
          <Grid item xs={12} sm={6}>
            <Typography variant="caption" color="text.secondary">
              Last Processed ID
            </Typography>
            <Typography 
              variant="h6" 
              color={color}
              sx={{ 
                fontSize: { xs: '1rem', sm: '1.25rem' },
                wordBreak: 'break-all'
              }}
            >
              {formatInteger(metrics.lastProcessedId)}
            </Typography>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Typography variant="caption" color="text.secondary">
              Total Processed
            </Typography>
            <Typography 
              variant="h6" 
              color={color}
              sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
            >
              {formatLargeNumber(metrics.totalProcessed)}
            </Typography>
          </Grid>

          {/* Row 2: Total Crawled and Request Count */}
          <Grid item xs={12} sm={6}>
            <Typography variant="caption" color="text.secondary">
              Total Crawled
            </Typography>
            <Typography 
              variant="h6" 
              color={color}
              sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
            >
              {formatLargeNumber(metrics.totalCrawled)}
            </Typography>
          </Grid>

          <Grid item xs={12} sm={6}>
            <Typography variant="caption" color="text.secondary">
              API Requests
            </Typography>
            <Typography 
              variant="h6" 
              color={color}
              sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
            >
              {formatInteger(metrics.requestCount)}
            </Typography>
          </Grid>

          {/* Row 3: Crawl Rates Section */}
          <Grid item xs={12}>
            <Box
              sx={{
                bgcolor: 'background.default',
                p: { xs: 1, sm: 1.5 },
                borderRadius: 1,
                mt: 1,
              }}
            >
              <Typography variant="caption" color="text.secondary" display="block" gutterBottom>
                Crawl Rates
              </Typography>
              <Grid container spacing={1}>
                <Grid item xs={12} sm={4}>
                  <Typography variant="caption" color="text.secondary" display="block">
                    Per Hour
                  </Typography>
                  <Typography variant="body2" fontWeight="medium">
                    {formatRate(metrics.ratePerHour, 2)}
                  </Typography>
                </Grid>
                <Grid item xs={12} sm={4}>
                  <Typography variant="caption" color="text.secondary" display="block">
                    Per Minute
                  </Typography>
                  <Typography variant="body2" fontWeight="medium">
                    {formatRate(metrics.ratePerMinute, 2)}
                  </Typography>
                </Grid>
                <Grid item xs={12} sm={4}>
                  <Typography variant="caption" color="text.secondary" display="block">
                    Per Second
                  </Typography>
                  <Typography variant="body2" fontWeight="medium">
                    {formatRate(metrics.ratePerSecond, 4)}
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
      <CardContent sx={{ p: { xs: 2, sm: 3 } }}>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <SpeedIcon sx={{ mr: 1, color: 'info.main', fontSize: { xs: 20, sm: 24 } }} />
          <Typography 
            variant="h6"
            sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
          >
            Crawler Performance Metrics
          </Typography>
        </Box>

        {/* Repository Crawler Section with distinct blue color */}
        {renderCrawlerSection(
          'Repository Crawler',
          <RepoIcon sx={{ color: 'primary.main', fontSize: 20 }} />,
          repoCrawler,
          'primary.main'
        )}

        {/* Visual divider between sections */}
        <Divider sx={{ my: 2 }} />

        {/* User Crawler Section with distinct green color */}
        {renderCrawlerSection(
          'User Crawler',
          <UserIcon sx={{ color: 'success.main', fontSize: 20 }} />,
          userCrawler,
          'success.main'
        )}

        <Typography 
          variant="caption" 
          color="text.secondary" 
          sx={{ 
            mt: 2, 
            display: 'block',
            fontSize: { xs: '0.7rem', sm: '0.75rem' }
          }}
        >
          Metrics based on last 1 hour of activity
        </Typography>
      </CardContent>
    </Card>
  )
}
