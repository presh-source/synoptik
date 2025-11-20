import { useQuery } from '@tanstack/react-query'
import { pipelineApi } from '@/api/endpoints'
import type { PipelineStatus } from '@/types'
import { logApiError, logInfo } from '@/utils/logger'

/**
 * Custom hook for fetching pipeline status with automatic polling and error recovery
 * 
 * Features:
 * - 30-second polling interval by default
 * - Response validation before returning data
 * - Automatic error recovery (continues polling after errors)
 * - Proper loading and error state handling
 * 
 * Requirements: 1.3, 8.1, 8.2, 8.5
 */
export const usePipelineStatus = (refetchInterval = 30000) => {
  return useQuery<PipelineStatus, Error>({
    queryKey: ['pipelineStatus'],
    queryFn: async () => {
      try {
        // API endpoint already validates response via validatePipelineStatusResponse
        const data = await pipelineApi.getStatus()
        
        logInfo('Pipeline status fetched successfully', {
          component: 'usePipelineStatus',
          action: 'fetch',
          extra: {
            lastProcessedId: data.coldPath.lastProcessedId,
            totalProcessed: data.coldPath.totalProcessed,
            errorRate: data.errorRates.coldPath,
          },
        })
        
        return data
      } catch (error) {
        // Log error with context
        logApiError(
          'Failed to fetch pipeline status',
          error,
          {
            component: 'usePipelineStatus',
            action: 'fetch',
          }
        )
        
        // Re-throw to let React Query handle the error state
        throw error
      }
    },
    // Polling configuration
    refetchInterval, // Default 30 seconds (30000ms)
    refetchIntervalInBackground: true, // Continue polling even when tab is not focused
    
    // Error recovery configuration
    retry: 3, // Retry failed requests up to 3 times
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000), // Exponential backoff: 1s, 2s, 4s, max 10s
    
    // Stale data configuration
    staleTime: 0, // Data is immediately stale, always refetch on mount
    refetchOnMount: true, // Refetch when component mounts
    refetchOnWindowFocus: true, // Refetch when window regains focus
    refetchOnReconnect: true, // Refetch when network reconnects
    
    // Keep previous data while fetching new data (smooth transitions)
    placeholderData: (previousData) => previousData,
  })
}
