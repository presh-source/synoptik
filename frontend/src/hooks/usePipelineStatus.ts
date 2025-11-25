import { useQuery } from '@tanstack/react-query'
import { useGetPipelineStatusQuery } from '@/graphql/generated/types'
import { pipelineApi } from '@/api/endpoints'
import type { PipelineStatus } from '@/types'
import { logApiError, logInfo, logWarn } from '@/utils/logger'
import { useEffect, useState } from 'react'

export const usePipelineStatus = (_refetchInterval = 0) => {
  const [isWindowFocused, setIsWindowFocused] = useState(true);

  useEffect(() => {
    const onFocus = () => setIsWindowFocused(true);
    const onBlur = () => setIsWindowFocused(false);

    window.addEventListener('focus', onFocus);
    window.addEventListener('blur', onBlur);

    return () => {
      window.removeEventListener('focus', onFocus);
      window.removeEventListener('blur', onBlur);
    };
  }, []);

  // Try GraphQL first with Apollo Client
  const {
    data: graphqlData,
    loading: graphqlLoading,
    error: graphqlError,
    refetch: graphqlRefetch,
  } = useGetPipelineStatusQuery({
    pollInterval: 0, // Disable polling as we use subscriptions
    fetchPolicy: 'cache-and-network',
    errorPolicy: 'all', // Return partial data even if there are errors
  })

  // Refetch GraphQL data when window regains focus
  useEffect(() => {
    if (isWindowFocused && graphqlRefetch) {
      graphqlRefetch();
    }
  }, [isWindowFocused, graphqlRefetch]);

  // Log successful GraphQL fetch
  useEffect(() => {
    if (graphqlData && !graphqlLoading) {
      logInfo('Pipeline status fetched successfully via GraphQL', {
        component: 'usePipelineStatus',
        action: 'fetch',
        extra: {
          lastProcessedId: graphqlData.pipelineStatus.coldPath.lastProcessedId,
          totalProcessed: graphqlData.pipelineStatus.coldPath.totalProcessed,
          errorRate: graphqlData.pipelineStatus.errorRates.coldPath,
        },
      })
    }
  }, [graphqlData, graphqlLoading])

  // Log GraphQL errors
  useEffect(() => {
    if (graphqlError) {
      logWarn('GraphQL query failed, will fall back to REST API', {
        component: 'usePipelineStatus',
        action: 'fetch',
        extra: {
          error: graphqlError.message,
        },
      })
    }
  }, [graphqlError])

  // Fallback to REST API if GraphQL fails
  const restQuery = useQuery<PipelineStatus, Error>({
    queryKey: ['pipelineStatus', 'rest'],
    queryFn: async () => {
      try {
        // API endpoint already validates response via validatePipelineStatusResponse
        const data = await pipelineApi.getStatus()

        logInfo('Pipeline status fetched successfully via REST API (fallback)', {
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
          'Failed to fetch pipeline status via REST API',
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
    // Only enable REST fallback if GraphQL has an error
    enabled: !!graphqlError && !graphqlLoading,

    // Polling configuration
    refetchInterval: false, // Disable polling
    refetchIntervalInBackground: false,

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

  // Transform GraphQL data to match the expected PipelineStatus interface
  const transformedGraphqlData = graphqlData?.pipelineStatus
    ? {
      coldPath: graphqlData.pipelineStatus.coldPath,
      errorRates: graphqlData.pipelineStatus.errorRates,
    }
    : undefined

  // Return GraphQL data if available, otherwise fall back to REST
  if (transformedGraphqlData) {
    return {
      data: transformedGraphqlData,
      isLoading: graphqlLoading,
      isError: !!graphqlError,
      error: graphqlError ? new Error(graphqlError.message) : null,
      refetch: () => {
        // Trigger refetch for Apollo Client
        return graphqlRefetch().then(result => {
          // Return in a shape compatible with what callers might expect (though mostly void/promise)
          return {
            data: result.data?.pipelineStatus ? {
              coldPath: result.data.pipelineStatus.coldPath,
              errorRates: result.data.pipelineStatus.errorRates
            } : undefined
          } as any;
        });
      },
    }
  }

  // Fall back to REST API
  return {
    data: restQuery.data,
    isLoading: restQuery.isLoading || graphqlLoading,
    isError: restQuery.isError || !!graphqlError,
    error: restQuery.error,
    refetch: restQuery.refetch,
  }
}
