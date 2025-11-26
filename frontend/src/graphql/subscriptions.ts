import { gql } from '@apollo/client';

/**
 * Subscription to receive real-time crawler completion events
 * Optionally filter by crawler type (repo or user)
 * 
 * @param crawlerType - Optional filter for crawler type ("repo" or "user")
 * 
 * Example usage:
 * ```typescript
 * const { data } = useSubscription(ON_CRAWLER_COMPLETED, {
 *   variables: { crawlerType: "repo" }
 * });
 * ```
 */
export const ON_CRAWLER_COMPLETED = gql`
  subscription OnCrawlerCompleted($crawlerType: String) {
    onCrawlerCompleted(crawlerType: $crawlerType) {
      crawlerType
      startId
      endId
      itemsFetched
      totalProcessed
      completedAt
    }
  }
`;

