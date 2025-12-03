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

export const GET_TELEMETRY_AGGREGATION = gql`
  query GetTelemetryAggregation(
    $organisation: String!
    $entity: String!
    $metricType: String!
    $start: String
    $end: String
  ) {
    getTelemetryAggregation(
      organisation: $organisation
      entity: $entity
      metricType: $metricType
      start: $start
      end: $end
    ) {
      organisation
      entity
      metricType
      period
      createdAt
      count
      
      # Retrieval Metrics
      totalRetrieval
      avgRetrieval
      minRetrieval
      maxRetrieval
      
      # Request Metrics
      errorCount
      errorRate
      
      # Run Metrics
      totalDuration
      avgDuration
      totalSize
      totalItems
      
      # CloudWatch Metrics
      coldStarts
      coldStartRate
      avgInitDuration
      avgMemoryUsed
    }
  }
`;

