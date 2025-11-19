import { Card, CardContent, Typography, Box, Alert, AlertTitle } from '@mui/material'
import { Error as ErrorIcon, CheckCircle as CheckIcon } from '@mui/icons-material'

interface ErrorRateIndicatorProps {
  errorRates: {
    coldPath: number
  }
}

export default function ErrorRateIndicator({ errorRates }: ErrorRateIndicatorProps) {
  const hasErrors = errorRates.coldPath > 5
  const hasWarnings = errorRates.coldPath > 1 && errorRates.coldPath <= 5

  const getSeverity = () => {
    if (hasErrors) return 'error'
    if (hasWarnings) return 'warning'
    return 'success'
  }

  const getTitle = () => {
    if (hasErrors) return 'High Error Rate Detected'
    if (hasWarnings) return 'Elevated Error Rate'
    return 'System Operational'
  }

  const getIcon = () => {
    if (hasErrors || hasWarnings) return <ErrorIcon />
    return <CheckIcon />
  }

  return (
    <Card>
      <CardContent>
        <Alert severity={getSeverity()} icon={getIcon()}>
          <AlertTitle>{getTitle()}</AlertTitle>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mt: 1 }}>
            <Box>
              <Typography variant="body2" fontWeight="bold">
                Cold Path Error Rate
              </Typography>
              <Typography
                variant="h6"
                color={errorRates.coldPath > 5 ? 'error.main' : 'text.primary'}
              >
                {errorRates.coldPath.toFixed(2)}%
              </Typography>
            </Box>
          </Box>
        </Alert>
      </CardContent>
    </Card>
  )
}
