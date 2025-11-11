import { useState } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  TextField,
  MenuItem,
  Button,
  Grid,
} from '@mui/material'
import { FilterList as FilterIcon } from '@mui/icons-material'
import type { MetricsFilters as MetricsFiltersType } from '@/types'

interface MetricsFiltersProps {
  onApplyFilters: (filters: MetricsFiltersType) => void
}

const POPULAR_LANGUAGES = [
  'All',
  'JavaScript',
  'Python',
  'Java',
  'TypeScript',
  'Go',
  'Rust',
  'C++',
  'C#',
  'Ruby',
  'PHP',
]

const POPULAR_LICENSES = [
  'All',
  'MIT',
  'Apache-2.0',
  'GPL-3.0',
  'BSD-3-Clause',
  'ISC',
  'LGPL-3.0',
  'MPL-2.0',
]

export default function MetricsFilters({ onApplyFilters }: MetricsFiltersProps) {
  const [language, setLanguage] = useState('All')
  const [license, setLicense] = useState('All')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  const handleApply = () => {
    const filters: MetricsFiltersType = {}
    if (language !== 'All') filters.language = language
    if (license !== 'All') filters.license = license
    if (dateFrom) filters.dateFrom = dateFrom
    if (dateTo) filters.dateTo = dateTo
    onApplyFilters(filters)
  }

  const handleReset = () => {
    setLanguage('All')
    setLicense('All')
    setDateFrom('')
    setDateTo('')
    onApplyFilters({})
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <FilterIcon sx={{ mr: 1 }} />
          <Typography variant="h6">Filters</Typography>
        </Box>

        <Grid container spacing={2}>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              label="Language"
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
              size="small"
            >
              {POPULAR_LANGUAGES.map((lang) => (
                <MenuItem key={lang} value={lang}>
                  {lang}
                </MenuItem>
              ))}
            </TextField>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              label="License"
              value={license}
              onChange={(e) => setLicense(e.target.value)}
              size="small"
            >
              {POPULAR_LICENSES.map((lic) => (
                <MenuItem key={lic} value={lic}>
                  {lic}
                </MenuItem>
              ))}
            </TextField>
          </Grid>

          <Grid item xs={12} sm={6} md={2}>
            <TextField
              fullWidth
              label="Date From"
              type="date"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
              size="small"
              InputLabelProps={{ shrink: true }}
            />
          </Grid>

          <Grid item xs={12} sm={6} md={2}>
            <TextField
              fullWidth
              label="Date To"
              type="date"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
              size="small"
              InputLabelProps={{ shrink: true }}
            />
          </Grid>

          <Grid item xs={12} md={2}>
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button variant="contained" onClick={handleApply} fullWidth>
                Apply
              </Button>
              <Button variant="outlined" onClick={handleReset} fullWidth>
                Reset
              </Button>
            </Box>
          </Grid>
        </Grid>
      </CardContent>
    </Card>
  )
}
