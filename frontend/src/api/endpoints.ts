import apiClient from './client'
import type { PipelineStatus } from '@/types'
import { validatePipelineStatusResponse } from '@/utils/validation'

export const pipelineApi = {
  getStatus: async (): Promise<PipelineStatus> => {
    const response = await apiClient.get<PipelineStatus>('/pipeline-status')
    // Validate and sanitize the response before returning
    return validatePipelineStatusResponse(response.data)
  },
}

export const metricsApi = {}
