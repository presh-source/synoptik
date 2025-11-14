import { Card, CardContent, Typography, Box, LinearProgress, Chip } from '@mui/material'
import { Storage as StorageIcon } from '@mui/icons-material'
import type { ColdPathStatus } from '@/types'

interface ColdPathStatusProps {
  data: ColdPathStatus
}

export default function ColdPathStatusCard({ data }: ColdPathStatusProps) {
  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num)
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <StorageIcon sx={{ mr: 1, color: 'primary.main' }} />
          <Typography variant="h6">Cold Path - Historical Ingestion</Typography>
        </Box>

        <Box sx={{ mb: 3 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
            <Typography variant="body2" color="text.secondary">
              Progress
            </Typography>
            <Typography variant="body2" fontWeight="bold">
              {data.progressPercentage.toFixed(2)}%
            </Typography>
          </Box>
          <LinearProgress
            variant="determinate"
            value={data.progressPercentage}
            sx={{ height: 8, borderRadius: 1 }}
          />
        </Box>

        <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Last Processed ID
            </Typography>
            <Typography variant="h6">{formatNumber(data.lastProcessedId)}</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Total Processed
            </Typography>
            <Typography variant="h6">{formatNumber(data.totalProcessed)}</Typography>
          </Box>
        </Box>

        <Box sx={{ mt: 2 }}>
          <Chip
            label={`Updated: ${new Date(data.updatedAt).toLocaleString()}`}
            size="small"
            variant="outlined"
          />
        </Box>
      </CardContent>
    </Card>
  )
}
