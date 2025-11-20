import { Box, Card, CardContent, Typography } from '@mui/material'
import { InfoOutlined as InfoIcon } from '@mui/icons-material'
import type { ReactNode } from 'react'

interface EmptyStateProps {
  title?: string
  message?: string
  icon?: ReactNode
}

/**
 * Empty state component for when data is unavailable
 * Requirement 8.3: Show placeholder values and indicate data is not available
 */
export default function EmptyState({ 
  title = 'No Data Available', 
  message = 'Data is currently unavailable. Please check back later.',
  icon = <InfoIcon sx={{ fontSize: 48, color: 'text.secondary', opacity: 0.5 }} />
}: EmptyStateProps) {
  return (
    <Card>
      <CardContent>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            py: 4,
            textAlign: 'center',
          }}
        >
          {icon}
          <Typography variant="h6" color="text.secondary" sx={{ mt: 2 }}>
            {title}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1, maxWidth: 400 }}>
            {message}
          </Typography>
        </Box>
      </CardContent>
    </Card>
  )
}
