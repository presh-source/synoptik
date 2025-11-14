import apiClient from './client'
import type { PipelineStatus, RealTimeMetrics, MetricsFilters } from '@/types'

export const pipelineApi = {
  getStatus: async (): Promise<PipelineStatus> => {
    const response = await apiClient.get<PipelineStatus>('/pipeline-status')
    return response.data
  },
}

export const metricsApi = {
  getRealTimeMetrics: async (filters?: MetricsFilters): Promise<RealTimeMetrics> => {
    const response = await apiClient.get<RealTimeMetrics>('/metrics/realtime', {
      params: filters,
    })
    return response.data
  },

  getTrendingRepositories: async (): Promise<RealTimeMetrics['trendingRepositories']> => {
    const response = await apiClient.get('/metrics/trending')
    return response.data
  },
}
