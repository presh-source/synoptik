import { gql } from '@apollo/client';

/**
 * Mutation to publish crawler completion event
 * This is typically called by crawler Lambdas, not the frontend
 * Included here for completeness and potential future admin UI use
 * 
 * @param input - CrawlerCompletedInput object with completion details
 * 
 * Note: This mutation requires IAM authentication when called from crawlers.
 * Frontend usage would require appropriate authorization configuration.
 */
export const PUBLISH_CRAWLER_COMPLETED = gql`
  mutation PublishCrawlerCompleted($input: CrawlerCompletedInput!) {
    publishCrawlerCompleted(input: $input) {
      crawlerType
      startId
      endId
      itemsFetched
      totalProcessed
      completedAt
      success
      errorMessage
    }
  }
`;
