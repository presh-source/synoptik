import { Card, CardContent, Typography, Box, Chip } from '@mui/material'
import { Bolt as BoltIcon } from '@mui/icons-material'
import type { HotPathStatus } from '@/types'

interface HotPathStatusProps {
  data: HotPathStatus
}

export default function HotPathStatusCard({ data }: HotPathStatusProps) {
  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num)
  }

  const getLagColor = (lag: number) => {
    if (lag < 1000) return 'success'
    if (lag < 60000) return 'warning'
    return 'error'
  }

  const formatLag = (lag: number) => {
    if (lag < 1000) return `${lag}ms`
    if (lag < 60000) return `${(lag / 1000).toFixed(1)}s`
    return `${(lag / 60000).toFixed(1)}m`
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <BoltIcon sx={{ mr: 1, color: 'warning.main' }} />
          <Typography variant="h6">Hot Path - Real-Time Events</Typography>
        </Box>

        <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Event Rate
            </Typography>
            <Typography variant="h6">{formatNumber(data.eventRate)}/min</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Kinesis Lag
            </Typography>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="h6">{formatLag(data.kinesisLag)}</Typography>
              <Chip
                label={data.kinesisLag < 1000 ? 'Healthy' : 'Delayed'}
                size="small"
                color={getLagColor(data.kinesisLag)}
              />
            </Box>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Processed (24h)
            </Typography>
            <Typography variant="h6">{formatNumber(data.processedLast24h)}</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Last Event
            </Typography>
            <Typography variant="body2">
              {new Date(data.lastEventTime).toLocaleString()}
            </Typography>
          </Box>
        </Box>
      </CardContent>
    </Card>
  )
}
