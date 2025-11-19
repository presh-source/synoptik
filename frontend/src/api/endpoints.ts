import apiClient from './client'
import type { PipelineStatus } from '@/types'

export const pipelineApi = {
  getStatus: async (): Promise<PipelineStatus> => {
    const response = await apiClient.get<PipelineStatus>('/pipeline-status')
    return response.data
  },
}

export const metricsApi = {}
