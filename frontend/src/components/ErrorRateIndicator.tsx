import { Card, CardContent, Typography, Box, Alert, AlertTitle } from '@mui/material'
import { Error as ErrorIcon, CheckCircle as CheckIcon, Warning as WarningIcon } from '@mui/icons-material'

interface ErrorRateIndicatorProps {
  errorRates: {
    coldPath: number
  }
}

export default function ErrorRateIndicator({ errorRates }: ErrorRateIndicatorProps) {
  const errorRate = errorRates.coldPath
  
  // Requirements 5.3, 5.4, 5.5: Thresholds for indicators
  const isError = errorRate > 10  // > 10% = error (red)
  const isWarning = errorRate >= 5 && errorRate <= 10  // 5-10% = warning (yellow)
  // < 5% = success (green) - handled in else branch

  const getSeverity = () => {
    if (isError) return 'error'
    if (isWarning) return 'warning'
    return 'success'
  }

  const getTitle = () => {
    if (isError) return 'High Error Rate Detected'
    if (isWarning) return 'Elevated Error Rate'
    return 'System Operational'
  }

  const getIcon = () => {
    if (isError) return <ErrorIcon />
    if (isWarning) return <WarningIcon />
    return <CheckIcon />
  }

  return (
    <Card>
      <CardContent sx={{ p: { xs: 2, sm: 3 } }}>
        <Alert 
          severity={getSeverity()} 
          icon={getIcon()}
          sx={{
            '& .MuiAlert-message': {
              width: '100%'
            }
          }}
        >
          <AlertTitle sx={{ fontSize: { xs: '0.95rem', sm: '1rem' } }}>
            {getTitle()}
          </AlertTitle>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mt: 1 }}>
            <Box>
              <Typography 
                variant="body2" 
                fontWeight="bold"
                sx={{ fontSize: { xs: '0.85rem', sm: '0.875rem' } }}
              >
                Cold Path Error Rate
              </Typography>
              <Typography
                variant="h6"
                color={isError ? 'error.main' : 'text.primary'}
                sx={{ fontSize: { xs: '1.25rem', sm: '1.5rem' } }}
              >
                {errorRate.toFixed(1)}%
              </Typography>
            </Box>
          </Box>
        </Alert>
      </CardContent>
    </Card>
  )
}
