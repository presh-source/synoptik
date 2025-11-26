import { gql } from '@apollo/client';

// Telemetry queries retained if needed for other components


export const GET_CRAWLER_STATE = gql`
  query GetCrawlerState($organisation: String!, $entity: String!) {
    getCrawlerState(organisation: $organisation, entity: $entity) {
      lastProcessedId
      totalProcessed
      itemsFetched
      updatedAt
    }
  }
`;

