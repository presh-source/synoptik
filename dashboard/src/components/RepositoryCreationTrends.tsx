import { Card, CardContent, Typography, Box } from '@mui/material'
import { Timeline as TimelineIcon } from '@mui/icons-material'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'
import type { RepositoryCreationTrend } from '@/types'

interface RepositoryCreationTrendsProps {
  data: RepositoryCreationTrend[]
}

export default function RepositoryCreationTrends({ data }: RepositoryCreationTrendsProps) {
  const chartData = data.map((item) => ({
    date: new Date(item.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
    count: item.count,
  }))

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <TimelineIcon sx={{ mr: 1, color: 'success.main' }} />
          <Typography variant="h6">Repository Creation Trends (30 Days)</Typography>
        </Box>

        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 12 }}
              angle={-45}
              textAnchor="end"
              height={80}
            />
            <YAxis
              tick={{ fontSize: 12 }}
              tickFormatter={(value) => new Intl.NumberFormat('en-US').format(value)}
            />
            <Tooltip
              formatter={(value: number) => [
                new Intl.NumberFormat('en-US').format(value),
                'Repositories',
              ]}
            />
            <Legend />
            <Line
              type="monotone"
              dataKey="count"
              stroke="#4caf50"
              strokeWidth={2}
              dot={{ r: 4 }}
              activeDot={{ r: 6 }}
              name="New Repositories"
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
