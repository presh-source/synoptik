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
  subscription OnCrawlerCompleted($organisation: String, $entity: String) {
    onCrawlerCompleted(organisation: $organisation, entity: $entity) {
      organisation
      entity
      itemsFetched
      lastProcessedId
      totalProcessed
      updatedAt
    }
  }
`;

