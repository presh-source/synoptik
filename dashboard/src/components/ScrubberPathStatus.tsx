import { Card, CardContent, Typography, Box, Chip } from '@mui/material'
import { CleaningServices as CleaningIcon } from '@mui/icons-material'
import type { ScrubberPathStatus } from '@/types'

interface ScrubberPathStatusProps {
  data: ScrubberPathStatus
}

export default function ScrubberPathStatusCard({ data }: ScrubberPathStatusProps) {
  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num)
  }

  const getQueueColor = (depth: number) => {
    if (depth < 10000) return 'success'
    if (depth < 100000) return 'warning'
    return 'error'
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <CleaningIcon sx={{ mr: 1, color: 'info.main' }} />
          <Typography variant="h6">Scrubber Path - Deletion Detection</Typography>
        </Box>

        <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Queue Depth
            </Typography>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="h6">{formatNumber(data.queueDepth)}</Typography>
              <Chip
                label={data.queueDepth < 10000 ? 'Low' : 'Processing'}
                size="small"
                color={getQueueColor(data.queueDepth)}
              />
            </Box>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Validation Rate
            </Typography>
            <Typography variant="h6">{formatNumber(data.validationRate)}/hr</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Deleted Repos
            </Typography>
            <Typography variant="h6">{formatNumber(data.deletedRepositories)}</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Last Run
            </Typography>
            <Typography variant="body2">
              {new Date(data.lastRunTime).toLocaleString()}
            </Typography>
          </Box>
        </Box>
      </CardContent>
    </Card>
  )
}
