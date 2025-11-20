// Pipeline Status Types

// Core crawler metrics structure with all 8 required fields
export interface CrawlerMetrics {
  lastProcessedId: number
  totalProcessed: number
  totalCrawled: number
  ratePerHour: number
  ratePerMinute: number
  ratePerSecond: number
  requestCount: number
  runCount: number
}

// Cold Path status structure
export interface ColdPathStatus {
  lastProcessedId: number
  totalProcessed: number
  updatedAt: string  // ISO 8601 format
  repoCrawler: CrawlerMetrics
  userCrawler: CrawlerMetrics
}

// Error rates structure
export interface ErrorRates {
  coldPath: number  // Percentage (0-100)
}

// Complete API response
export interface PipelineStatusResponse {
  coldPath: ColdPathStatus
  errorRates: ErrorRates
}

// Legacy alias for backward compatibility
export type PipelineStatus = PipelineStatusResponse
