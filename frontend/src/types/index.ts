// Pipeline Status Types
export interface ColdPathStatus {
  lastProcessedId: number
  totalProcessed: number
  progressPercentage: number
  updatedAt: string
}

export interface HotPathStatus {
  eventRate: number
  kinesisLag: number
  lastEventTime: string
  processedLast24h: number
}

export interface ScrubberPathStatus {
  queueDepth: number
  validationRate: number
  deletedRepositories: number
  lastRunTime: string
}

export interface PipelineStatus {
  coldPath: ColdPathStatus
  hotPath: HotPathStatus
  scrubberPath: ScrubberPathStatus
  errorRates: {
    coldPath: number
    hotPath: number
    scrubberPath: number
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
