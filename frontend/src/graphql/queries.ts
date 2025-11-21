import { gql } from '@apollo/client';

/**
 * Query to get complete pipeline status including all crawlers and error rates
 * Returns the full state of the cold path pipeline with metrics for both crawlers
 */
export const GET_PIPELINE_STATUS = gql`
  query GetPipelineStatus {
    pipelineStatus {
      coldPath {
        lastProcessedId
        totalProcessed
        updatedAt
        repoCrawler {
          lastProcessedId
          totalProcessed
          totalCrawled
          ratePerHour
          ratePerMinute
          ratePerSecond
          requestCount
          runCount
        }
        userCrawler {
          lastProcessedId
          totalProcessed
          totalCrawled
          ratePerHour
          ratePerMinute
          ratePerSecond
          requestCount
          runCount
        }
      }
      errorRates {
        coldPath
      }
    }
  }
`;

/**
 * Query to get repository crawler metrics for a specific time period
 * @param timePeriodHours - Number of hours to look back (default: 1)
 */
export const GET_REPO_CRAWLER_METRICS = gql`
  query GetRepoCrawlerMetrics($timePeriodHours: Int) {
    repoCrawler(timePeriodHours: $timePeriodHours) {
      lastProcessedId
      totalProcessed
      totalCrawled
      ratePerHour
      ratePerMinute
      ratePerSecond
      requestCount
      runCount
    }
  }
`;

/**
 * Query to get user crawler metrics for a specific time period
 * @param timePeriodHours - Number of hours to look back (default: 1)
 */
export const GET_USER_CRAWLER_METRICS = gql`
  query GetUserCrawlerMetrics($timePeriodHours: Int) {
    userCrawler(timePeriodHours: $timePeriodHours) {
      lastProcessedId
      totalProcessed
      totalCrawled
      ratePerHour
      ratePerMinute
      ratePerSecond
      requestCount
      runCount
    }
  }
`;

/**
 * Query to get error rates for the cold path pipeline
 */
export const GET_ERROR_RATES = gql`
  query GetErrorRates {
    errorRates {
      coldPath
    }
  }
`;
