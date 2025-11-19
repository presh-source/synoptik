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

// Real-Time Metrics Types
export interface TrendingRepository {
  id: number
  fullName: string
  description: string
  language: string
  stargazersCount: number
  forksCount: number
  starsLast24h: number
}

export interface LanguageDistribution {
  language: string
  count: number
  percentage: number
}

export interface RepositoryCreationTrend {
  date: string
  count: number
}

export interface RealTimeMetrics {
  trendingRepositories: TrendingRepository[]
  languageDistribution: LanguageDistribution[]
  creationTrends: RepositoryCreationTrend[]
}

export interface MetricsFilters {
  language?: string
  license?: string
  dateFrom?: string
  dateTo?: string
}
