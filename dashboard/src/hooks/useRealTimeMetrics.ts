import { useQuery } from '@tanstack/react-query'
import { metricsApi } from '@/api/endpoints'
import type { MetricsFilters } from '@/types'

export const useRealTimeMetrics = (filters?: MetricsFilters, refetchInterval = 60000) => {
  return useQuery({
    queryKey: ['realTimeMetrics', filters],
    queryFn: () => metricsApi.getRealTimeMetrics(filters),
    refetchInterval,
  })
}

export const useTrendingRepositories = (refetchInterval = 60000) => {
  return useQuery({
    queryKey: ['trendingRepositories'],
    queryFn: metricsApi.getTrendingRepositories,
    refetchInterval,
  })
}
