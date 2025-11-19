// Pipeline Status Types
export interface CrawlerMetrics {
  totalCrawled: number
  ratePerHour: number
  ratePerMinute: number
  ratePerSecond: number
  requestCount: number
  runCount: number
}

export interface ColdPathStatus {
  lastProcessedId: number
  totalProcessed: number
  updatedAt: string
  repoCrawler?: CrawlerMetrics
  userCrawler?: CrawlerMetrics
}

export interface PipelineStatus {
  coldPath: ColdPathStatus
  errorRates: {
    coldPath: number
  }
}
