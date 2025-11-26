/**
 * Number formatting utilities for the crawler metrics dashboard
 * 
 * These functions format numbers according to the requirements:
 * - Large numbers with thousand separators
 * - Rates with configurable decimal precision
 * - Integers without decimals
 * - Percentages with 1 decimal place
 */

/**
 * Formats a large number with thousand separators
 * 
 * @param value - The number to format
 * @returns Formatted string with commas as thousand separators
 * 
 * @example
 * formatLargeNumber(1234567) // "1,234,567"
 * formatLargeNumber(1000) // "1,000"
 * formatLargeNumber(999) // "999"
 * formatLargeNumber(0) // "0"
 */
export function formatLargeNumber(value: number): string {
  return value.toLocaleString('en-US')
}

/**
 * Formats a rate with configurable decimal precision
 * 
 * @param value - The rate value to format
 * @param decimals - Number of decimal places (default: 2)
 * @returns Formatted string with specified decimal precision
 * 
 * @example
 * formatRate(1234.5678, 2) // "1,234.57"
 * formatRate(0.3430, 4) // "0.3430"
 * formatRate(20.58, 2) // "20.58"
 */
export function formatRate(value: number, decimals: number = 2): string {
  return value.toLocaleString('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })
}

/**
 * Formats an integer without decimal places
 * 
 * @param value - The number to format as an integer
 * @returns Formatted string without decimals, with thousand separators
 * 
 * @example
 * formatInteger(1234567) // "1,234,567"
 * formatInteger(1234.56) // "1,235" (rounds to nearest integer)
 * formatInteger(0) // "0"
 */
export function formatInteger(value: number): string {
  return Math.round(value).toLocaleString('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })
}

/**
 * Formats a percentage with 1 decimal place
 * 
 * @param value - The percentage value (0-100)
 * @returns Formatted string with 1 decimal place and % symbol
 * 
 * @example
 * formatPercentage(5.67) // "5.7%"
 * formatPercentage(10.0) // "10.0%"
 * formatPercentage(0.5) // "0.5%"
 */
export function formatPercentage(value: number): string {
  return `${value.toLocaleString('en-US', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })}%`
}

/**
 * Formats an ISO 8601 timestamp for human-readable display
 * Converts to user's local timezone and includes both date and time
 * 
 * @param isoTimestamp - ISO 8601 timestamp string
 * @returns Formatted string with date and time in local timezone
 * 
 * @example
 * formatTimestamp("2025-11-20T04:41:00Z") // "Nov 20, 2025, 4:41:00 AM" (in user's timezone)
 */
export function formatTimestamp(isoTimestamp: string): string {
  const date = new Date(isoTimestamp)
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
    hour12: true,
  })
}


