import { Card, CardContent, Typography, Box } from '@mui/material'
import { Code as CodeIcon } from '@mui/icons-material'
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts'
import type { LanguageDistribution as LanguageDistributionType } from '@/types'

interface LanguageDistributionProps {
  data: LanguageDistributionType[]
}

const COLORS = [
  '#2196f3',
  '#f50057',
  '#4caf50',
  '#ff9800',
  '#9c27b0',
  '#00bcd4',
  '#ffeb3b',
  '#e91e63',
  '#3f51b5',
  '#8bc34a',
]

export default function LanguageDistribution({ data }: LanguageDistributionProps) {
  const chartData = data.map((item) => ({
    name: item.language,
    value: item.count,
    percentage: item.percentage,
  }))

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <CodeIcon sx={{ mr: 1, color: 'primary.main' }} />
          <Typography variant="h6">Language Distribution</Typography>
        </Box>

        <ResponsiveContainer width="100%" height={300}>
          <PieChart>
            <Pie
              data={chartData}
              cx="50%"
              cy="50%"
              labelLine={false}
              label={({ name, percentage }) => `${name} ${percentage.toFixed(1)}%`}
              outerRadius={80}
              fill="#8884d8"
              dataKey="value"
            >
              {chartData.map((_entry, index) => (
                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip
              formatter={(value: number) => new Intl.NumberFormat('en-US').format(value)}
            />
            <Legend />
          </PieChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
