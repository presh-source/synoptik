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

export const GET_DASHBOARD_METRICS = gql`
  query GetDashboardMetrics(
    $organisation: String!
    $entity: String!
    $start: String
    $end: String
  ) {
    retrievals: getTelemetryAggregation(
      organisation: $organisation
      entity: $entity
      metricType: "retrievals"
      start: $start
      end: $end
    ) {
      createdAt
      totalRetrieval
      avgRetrieval
    }
    requests: getTelemetryAggregation(
      organisation: $organisation
      entity: $entity
      metricType: "requests"
      start: $start
      end: $end
    ) {
      createdAt
      count
      errorCount
    }
    runs: getTelemetryAggregation(
      organisation: $organisation
      entity: $entity
      metricType: "runs"
      start: $start
      end: $end
    ) {
      createdAt
      avgDuration
      avgMemoryUsed
    }
  }
`;

