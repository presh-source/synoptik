import { Card, CardContent, Typography, Box, Chip } from '@mui/material'
import { Storage as StorageIcon, Warning as WarningIcon } from '@mui/icons-material'
import type { ColdPathStatus } from '@/types'
import { formatInteger, formatTimestamp, isStale } from '@/utils/formatting'

interface ColdPathStatusProps {
  data: ColdPathStatus
}

export default function ColdPathStatusCard({ data }: ColdPathStatusProps) {
  const dataIsStale = isStale(data.updatedAt)

  return (
    <Card>
      <CardContent sx={{ p: { xs: 2, sm: 3 } }}>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <StorageIcon sx={{ mr: 1, color: 'primary.main', fontSize: { xs: 20, sm: 24 } }} />
          <Typography 
            variant="h6"
            sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
          >
            Cold Path - Historical Ingestion
          </Typography>
        </Box>

        <Box 
          sx={{ 
            display: 'grid', 
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, 
            gap: 2, 
            mb: 3 
          }}
        >
          <Box>
            <Typography variant="body2" color="text.secondary">
              Last Processed ID
            </Typography>
            <Typography 
              variant="h6"
              sx={{ 
                fontSize: { xs: '1rem', sm: '1.25rem' },
                wordBreak: 'break-all'
              }}
            >
              {formatInteger(data.lastProcessedId)}
            </Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">
              Total Processed
            </Typography>
            <Typography 
              variant="h6"
              sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
            >
              {formatInteger(data.totalProcessed)}
            </Typography>
          </Box>
        </Box>

        <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
          <Chip
            label={`Updated: ${formatTimestamp(data.updatedAt)}`}
            size="small"
            variant="outlined"
          />
          {dataIsStale && (
            <Chip
              icon={<WarningIcon />}
              label="Data is stale (>5 min old)"
              size="small"
              color="warning"
              variant="outlined"
            />
          )}
        </Box>
      </CardContent>
    </Card>
  )
}
