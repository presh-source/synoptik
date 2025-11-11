import { useQuery } from '@tanstack/react-query'
import { pipelineApi } from '@/api/endpoints'

export const usePipelineStatus = (refetchInterval = 30000) => {
  return useQuery({
    queryKey: ['pipelineStatus'],
    queryFn: pipelineApi.getStatus,
    refetchInterval,
  })
}
