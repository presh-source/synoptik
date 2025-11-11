import { Card, CardContent, Typography, Box, List, ListItem, ListItemText, Chip } from '@mui/material'
import { Star as StarIcon, TrendingUp as TrendingIcon } from '@mui/icons-material'
import type { TrendingRepository } from '@/types'

interface TrendingRepositoriesProps {
  repositories: TrendingRepository[]
}

export default function TrendingRepositories({ repositories }: TrendingRepositoriesProps) {
  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num)
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <TrendingIcon sx={{ mr: 1, color: 'warning.main' }} />
          <Typography variant="h6">Trending Repositories (24h)</Typography>
        </Box>

        <List>
          {repositories.map((repo, index) => (
            <ListItem
              key={repo.id}
              sx={{
                borderBottom: index < repositories.length - 1 ? 1 : 0,
                borderColor: 'divider',
                px: 0,
              }}
            >
              <Box sx={{ mr: 2, minWidth: 30 }}>
                <Typography variant="h6" color="primary">
                  #{index + 1}
                </Typography>
              </Box>
              <ListItemText
                primary={
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
                    <Typography variant="subtitle1" fontWeight="bold">
                      {repo.fullName}
                    </Typography>
                    {repo.language && (
                      <Chip label={repo.language} size="small" variant="outlined" />
                    )}
                  </Box>
                }
                secondary={
                  <Box>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                      {repo.description || 'No description'}
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                        <StarIcon sx={{ fontSize: 16 }} />
                        <Typography variant="body2">{formatNumber(repo.stargazersCount)}</Typography>
                      </Box>
                      <Chip
                        label={`+${formatNumber(repo.starsLast24h)} today`}
                        size="small"
                        color="success"
                        icon={<TrendingIcon />}
                      />
                    </Box>
                  </Box>
                }
              />
            </ListItem>
          ))}
        </List>
      </CardContent>
    </Card>
  )
}
