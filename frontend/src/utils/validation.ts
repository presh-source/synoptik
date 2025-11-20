import type { 
  PipelineStatusResponse, 
  ColdPathStatus, 
  CrawlerMetrics, 
  ErrorRates 
} from '@/types'
import { logValidationError, logValidationWarn } from './logger'

/**
 * Validates and sanitizes a CrawlerMetrics object
 * Ensures all required fields are present with correct types
 */
export function validateCrawlerMetrics(
  data: unknown,
  crawlerType: string
): CrawlerMetrics {
  const obj = data as Partial<CrawlerMetrics>

  // Check if data is an object
  if (!obj || typeof obj !== 'object') {
    logValidationWarn(
      `Invalid ${crawlerType} crawler metrics object, using defaults`,
      { extra: { crawlerType, receivedType: typeof data } }
    )
    return getDefaultCrawlerMetrics()
  }

  const validated: CrawlerMetrics = {
    lastProcessedId: coerceToNumber(obj.lastProcessedId, 'lastProcessedId', crawlerType),
    totalProcessed: coerceToNumber(obj.totalProcessed, 'totalProcessed', crawlerType),
    totalCrawled: coerceToNumber(obj.totalCrawled, 'totalCrawled', crawlerType),
    ratePerHour: coerceToNumber(obj.ratePerHour, 'ratePerHour', crawlerType),
    ratePerMinute: coerceToNumber(obj.ratePerMinute, 'ratePerMinute', crawlerType),
    ratePerSecond: coerceToNumber(obj.ratePerSecond, 'ratePerSecond', crawlerType),
    requestCount: coerceToNumber(obj.requestCount, 'requestCount', crawlerType),
    runCount: coerceToNumber(obj.runCount, 'runCount', crawlerType),
  }

  return validated
}

/**
 * Validates and sanitizes a ColdPathStatus object
 */
export function validateColdPathStatus(data: unknown): ColdPathStatus {
  const obj = data as Partial<ColdPathStatus>

  // Check if data is an object
  if (!obj || typeof obj !== 'object') {
    logValidationError(
      'Invalid coldPath object, using defaults',
      { extra: { receivedType: typeof data } }
    )
    return getDefaultColdPathStatus()
  }

  // Validate required fields
  const validated: ColdPathStatus = {
    lastProcessedId: coerceToNumber(obj.lastProcessedId, 'lastProcessedId', 'coldPath'),
    totalProcessed: coerceToNumber(obj.totalProcessed, 'totalProcessed', 'coldPath'),
    updatedAt: coerceToString(obj.updatedAt, 'updatedAt', 'coldPath'),
    repoCrawler: validateCrawlerMetrics(obj.repoCrawler, 'repo'),
    userCrawler: validateCrawlerMetrics(obj.userCrawler, 'user'),
  }

  return validated
}

/**
 * Validates and sanitizes an ErrorRates object
 */
export function validateErrorRates(data: unknown): ErrorRates {
  const obj = data as Partial<ErrorRates>

  // Check if data is an object
  if (!obj || typeof obj !== 'object') {
    logValidationWarn(
      'Invalid errorRates object, using defaults',
      { extra: { receivedType: typeof data } }
    )
    return getDefaultErrorRates()
  }

  const validated: ErrorRates = {
    coldPath: coerceToNumber(obj.coldPath, 'coldPath', 'errorRates'),
  }

  return validated
}

/**
 * Validates and sanitizes the complete PipelineStatusResponse
 */
export function validatePipelineStatusResponse(
  data: unknown
): PipelineStatusResponse {
  const obj = data as Partial<PipelineStatusResponse>

  // Check if data is an object
  if (!obj || typeof obj !== 'object') {
    logValidationError(
      'Invalid pipeline status response, using defaults',
      { extra: { receivedType: typeof data } }
    )
    return getDefaultPipelineStatusResponse()
  }

  // Validate top-level structure
  if (!obj.coldPath) {
    logValidationError('Missing required field: coldPath')
  }

  if (!obj.errorRates) {
    logValidationError('Missing required field: errorRates')
  }

  const validated: PipelineStatusResponse = {
    coldPath: validateColdPathStatus(obj.coldPath),
    errorRates: validateErrorRates(obj.errorRates),
  }

  return validated
}

/**
 * Coerces a value to a number, with logging for type mismatches
 */
function coerceToNumber(
  value: unknown,
  fieldName: string,
  context: string
): number {
  // If value is already a number, return it
  if (typeof value === 'number' && !isNaN(value)) {
    return value
  }

  // If value is missing or null/undefined, use default
  if (value === null || value === undefined) {
    logValidationWarn(
      `Missing field: ${context}.${fieldName}, using default value 0`,
      { extra: { context, fieldName } }
    )
    return 0
  }

  // Try to coerce to number
  const coerced = Number(value)
  if (!isNaN(coerced)) {
    logValidationError(
      `Type mismatch for ${context}.${fieldName}: expected number, got ${typeof value}, coerced to ${coerced}`,
      { extra: { context, fieldName, originalValue: value, originalType: typeof value, coercedValue: coerced } }
    )
    return coerced
  }

  // If coercion fails, use default
  logValidationError(
    `Failed to coerce ${context}.${fieldName} to number: ${value}, using default value 0`,
    { extra: { context, fieldName, value } }
  )
  return 0
}

/**
 * Coerces a value to a string, with logging for type mismatches
 */
function coerceToString(
  value: unknown,
  fieldName: string,
  context: string
): string {
  // If value is already a string, return it
  if (typeof value === 'string') {
    return value
  }

  // If value is missing or null/undefined, use default
  if (value === null || value === undefined) {
    logValidationWarn(
      `Missing field: ${context}.${fieldName}, using default value ""`,
      { extra: { context, fieldName } }
    )
    return ''
  }

  // Try to coerce to string
  const coerced = String(value)
  logValidationError(
    `Type mismatch for ${context}.${fieldName}: expected string, got ${typeof value}, coerced to "${coerced}"`,
    { extra: { context, fieldName, originalValue: value, originalType: typeof value, coercedValue: coerced } }
  )
  return coerced
}

/**
 * Default values for CrawlerMetrics
 */
function getDefaultCrawlerMetrics(): CrawlerMetrics {
  return {
    lastProcessedId: 0,
    totalProcessed: 0,
    totalCrawled: 0,
    ratePerHour: 0,
    ratePerMinute: 0,
    ratePerSecond: 0,
    requestCount: 0,
    runCount: 0,
  }
}

/**
 * Default values for ColdPathStatus
 */
function getDefaultColdPathStatus(): ColdPathStatus {
  return {
    lastProcessedId: 0,
    totalProcessed: 0,
    updatedAt: new Date().toISOString(),
    repoCrawler: getDefaultCrawlerMetrics(),
    userCrawler: getDefaultCrawlerMetrics(),
  }
}

/**
 * Default values for ErrorRates
 */
function getDefaultErrorRates(): ErrorRates {
  return {
    coldPath: 0,
  }
}

/**
 * Default values for PipelineStatusResponse
 */
function getDefaultPipelineStatusResponse(): PipelineStatusResponse {
  return {
    coldPath: getDefaultColdPathStatus(),
    errorRates: getDefaultErrorRates(),
  }
}
