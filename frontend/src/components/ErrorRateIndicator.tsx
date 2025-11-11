import { Card, CardContent, Typography, Box, Alert, AlertTitle } from '@mui/material'
import { Error as ErrorIcon, CheckCircle as CheckIcon } from '@mui/icons-material'

interface ErrorRateIndicatorProps {
  errorRates: {
    coldPath: number
    hotPath: number
    scrubberPath: number
  }
}

export default function ErrorRateIndicator({ errorRates }: ErrorRateIndicatorProps) {
  const hasErrors = Object.values(errorRates).some((rate) => rate > 5)
  const hasWarnings = Object.values(errorRates).some((rate) => rate > 1 && rate <= 5)

  const getSeverity = () => {
    if (hasErrors) return 'error'
    if (hasWarnings) return 'warning'
    return 'success'
  }

  const getTitle = () => {
    if (hasErrors) return 'High Error Rate Detected'
    if (hasWarnings) return 'Elevated Error Rate'
    return 'All Systems Operational'
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
          <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 2, mt: 1 }}>
            <Box>
              <Typography variant="body2" fontWeight="bold">
                Cold Path
              </Typography>
              <Typography
                variant="h6"
                color={errorRates.coldPath > 5 ? 'error.main' : 'text.primary'}
              >
                {errorRates.coldPath.toFixed(2)}%
              </Typography>
            </Box>
            <Box>
              <Typography variant="body2" fontWeight="bold">
                Hot Path
              </Typography>
              <Typography
                variant="h6"
                color={errorRates.hotPath > 5 ? 'error.main' : 'text.primary'}
              >
                {errorRates.hotPath.toFixed(2)}%
              </Typography>
            </Box>
            <Box>
              <Typography variant="body2" fontWeight="bold">
                Scrubber Path
              </Typography>
              <Typography
                variant="h6"
                color={errorRates.scrubberPath > 5 ? 'error.main' : 'text.primary'}
              >
                {errorRates.scrubberPath.toFixed(2)}%
              </Typography>
            </Box>
          </Box>
        </Alert>
      </CardContent>
    </Card>
  )
}
