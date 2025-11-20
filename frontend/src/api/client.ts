import axios, { AxiosError } from 'axios'
import { logApiError, logDebug } from '@/utils/logger'

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL || (import.meta.env.DEV ? 'http://localhost:3001' : `https://api.dev.${import.meta.env.VITE_PROJECT_NAME}.dev`),
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor
apiClient.interceptors.request.use(
  (config) => {
    logDebug(`API Request: ${config.method?.toUpperCase()} ${config.url}`, {
      component: 'apiClient',
      extra: { method: config.method, url: config.url },
    })
    return config
  },
  (error) => {
    logApiError('API Request Error', error, {
      component: 'apiClient',
      action: 'request',
    })
    return Promise.reject(error)
  }
)

// Response interceptor
apiClient.interceptors.response.use(
  (response) => {
    logDebug(`API Response: ${response.status} ${response.config.url}`, {
      component: 'apiClient',
      extra: { 
        status: response.status, 
        url: response.config.url,
        dataSize: JSON.stringify(response.data).length,
      },
    })
    return response
  },
  (error: AxiosError) => {
    // Extract error details
    const status = error.response?.status
    const statusText = error.response?.statusText
    const url = error.config?.url
    const method = error.config?.method
    
    // Log detailed error information
    logApiError(
      `API Error: ${method?.toUpperCase()} ${url} - ${status || 'Network Error'}`,
      error,
      {
        component: 'apiClient',
        action: 'response',
        extra: {
          url,
          method,
          status,
          statusText,
          message: error.message,
          code: error.code,
          isNetworkError: !error.response,
          responseData: error.response?.data,
        },
      }
    )
    
    return Promise.reject(error)
  }
)

export default apiClient
