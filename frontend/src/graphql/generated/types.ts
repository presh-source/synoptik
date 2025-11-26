import { gql } from '@apollo/client';
import * as ApolloReactCommon from '@apollo/client/react';
import * as ApolloReactHooks from '@apollo/client/react';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
const defaultOptions = {} as const;
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  AWSDate: { input: any; output: any; }
  AWSDateTime: { input: string; output: string; }
  AWSEmail: { input: any; output: any; }
  AWSIPAddress: { input: any; output: any; }
  AWSJSON: { input: any; output: any; }
  AWSPhone: { input: any; output: any; }
  AWSTime: { input: any; output: any; }
  AWSTimestamp: { input: any; output: any; }
  AWSURL: { input: any; output: any; }
};

export type BookmarkData = {
  __typename?: 'BookmarkData';
  crawler_type: Scalars['String']['output'];
  last_processed_id: Scalars['Int']['output'];
  total_processed: Scalars['Int']['output'];
  total_requests: Scalars['Int']['output'];
  total_runs: Scalars['Int']['output'];
  total_size: Scalars['Int']['output'];
  updated_at: Scalars['AWSDateTime']['output'];
};

export type ColdPathStatus = {
  __typename?: 'ColdPathStatus';
  lastProcessedId: Scalars['Int']['output'];
  repoCrawler: CrawlerMetrics;
  totalProcessed: Scalars['Int']['output'];
  updatedAt: Scalars['AWSDateTime']['output'];
  userCrawler: CrawlerMetrics;
};

export type CrawlerCompleted = {
  __typename?: 'CrawlerCompleted';
  completedAt: Scalars['AWSDateTime']['output'];
  crawlerType: Scalars['String']['output'];
  endId: Scalars['Int']['output'];
  itemsFetched: Scalars['Int']['output'];
  startId: Scalars['Int']['output'];
  totalProcessed: Scalars['Int']['output'];
};

export type CrawlerCompletedInput = {
  completedAt?: InputMaybe<Scalars['AWSDateTime']['input']>;
  crawlerType: Scalars['String']['input'];
  endId: Scalars['Int']['input'];
  itemsFetched: Scalars['Int']['input'];
  startId: Scalars['Int']['input'];
  totalProcessed: Scalars['Int']['input'];
};

export type CrawlerMetrics = {
  __typename?: 'CrawlerMetrics';
  lastProcessedId: Scalars['Int']['output'];
  ratePerHour: Scalars['Float']['output'];
  ratePerMinute: Scalars['Float']['output'];
  ratePerSecond: Scalars['Float']['output'];
  requestCount: Scalars['Int']['output'];
  runCount: Scalars['Int']['output'];
  totalCrawled: Scalars['Int']['output'];
  totalProcessed: Scalars['Int']['output'];
};

export type CrawlerStats = {
  __typename?: 'CrawlerStats';
  repo: CrawlerTypeStats;
  user: CrawlerTypeStats;
};

export type CrawlerTypeStats = {
  __typename?: 'CrawlerTypeStats';
  avg_items_per_hour: Scalars['Float']['output'];
  last_run?: Maybe<Scalars['AWSDateTime']['output']>;
  total_processed: Scalars['Int']['output'];
  total_runs: Scalars['Int']['output'];
  total_size: Scalars['Int']['output'];
};

export type ErrorRates = {
  __typename?: 'ErrorRates';
  coldPath: Scalars['Float']['output'];
};

export type HourlyAggregation = {
  __typename?: 'HourlyAggregation';
  average: Scalars['Float']['output'];
  count: Scalars['Int']['output'];
  crawler_type: Scalars['String']['output'];
  created_at: Scalars['AWSDateTime']['output'];
  hour: Scalars['String']['output'];
  max: Scalars['Int']['output'];
  metric_type: Scalars['String']['output'];
  min: Scalars['Int']['output'];
  total: Scalars['Int']['output'];
};

export type Mutation = {
  __typename?: 'Mutation';
  publishCrawlerCompleted: CrawlerCompleted;
};


export type MutationPublishCrawlerCompletedArgs = {
  input: CrawlerCompletedInput;
};

export type PipelineStatus = {
  __typename?: 'PipelineStatus';
  coldPath: ColdPathStatus;
  errorRates: ErrorRates;
};

export type Query = {
  __typename?: 'Query';
  /** Get error rates for the cold path pipeline */
  errorRates: ErrorRates;
  getBookmark?: Maybe<BookmarkData>;
  getCrawlerStats?: Maybe<CrawlerStats>;
  getRunRequests: Array<RequestData>;
  listHourlyAggregations: Array<HourlyAggregation>;
  listRunsByType?: Maybe<RunDataConnection>;
  /** Get complete pipeline status including all crawlers and error rates */
  pipelineStatus: PipelineStatus;
  /** Get repository crawler metrics for a specific time period */
  repoCrawler: CrawlerMetrics;
  /** Get user crawler metrics for a specific time period */
  userCrawler: CrawlerMetrics;
};


export type QueryGetBookmarkArgs = {
  crawler_type: Scalars['String']['input'];
};


export type QueryGetCrawlerStatsArgs = {
  timeRange: Scalars['String']['input'];
};


export type QueryGetRunRequestsArgs = {
  run_id: Scalars['ID']['input'];
};


export type QueryListHourlyAggregationsArgs = {
  crawler_type: Scalars['String']['input'];
  endHour: Scalars['String']['input'];
  metric_type: Scalars['String']['input'];
  startHour: Scalars['String']['input'];
};


export type QueryListRunsByTypeArgs = {
  crawler_type: Scalars['String']['input'];
  limit?: InputMaybe<Scalars['Int']['input']>;
  nextToken?: InputMaybe<Scalars['String']['input']>;
};


export type QueryRepoCrawlerArgs = {
  timePeriodHours?: InputMaybe<Scalars['Int']['input']>;
};


export type QueryUserCrawlerArgs = {
  timePeriodHours?: InputMaybe<Scalars['Int']['input']>;
};

export type RequestData = {
  __typename?: 'RequestData';
  crawler_type: Scalars['String']['output'];
  created_at: Scalars['AWSDateTime']['output'];
  rate_limit: Scalars['Int']['output'];
  rate_limit_remaining: Scalars['Int']['output'];
  rate_limit_reset: Scalars['Int']['output'];
  request_end: Scalars['AWSDateTime']['output'];
  request_start: Scalars['AWSDateTime']['output'];
  retrieval: Scalars['Int']['output'];
  run_id: Scalars['ID']['output'];
  since_id: Scalars['Int']['output'];
  status_code: Scalars['Int']['output'];
};

export type RunData = {
  __typename?: 'RunData';
  crawler_type: Scalars['String']['output'];
  created_at: Scalars['AWSDateTime']['output'];
  duration_ms: Scalars['Int']['output'];
  request_count: Scalars['Int']['output'];
  retrieval: Scalars['Int']['output'];
  run_id: Scalars['ID']['output'];
  size: Scalars['Int']['output'];
};

export type RunDataConnection = {
  __typename?: 'RunDataConnection';
  items: Array<RunData>;
  nextToken?: Maybe<Scalars['String']['output']>;
};

export type Subscription = {
  __typename?: 'Subscription';
  /** Subscribe to crawler completion events, optionally filtered by crawler type */
  onCrawlerCompleted?: Maybe<CrawlerCompleted>;
};


export type SubscriptionOnCrawlerCompletedArgs = {
  crawlerType?: InputMaybe<Scalars['String']['input']>;
};

export type PublishCrawlerCompletedMutationVariables = Exact<{
  input: CrawlerCompletedInput;
}>;


export type PublishCrawlerCompletedMutation = { __typename?: 'Mutation', publishCrawlerCompleted: { __typename?: 'CrawlerCompleted', crawlerType: string, startId: number, endId: number, itemsFetched: number, totalProcessed: number, completedAt: string } };

export type GetPipelineStatusQueryVariables = Exact<{ [key: string]: never; }>;


export type GetPipelineStatusQuery = { __typename?: 'Query', pipelineStatus: { __typename?: 'PipelineStatus', coldPath: { __typename?: 'ColdPathStatus', lastProcessedId: number, totalProcessed: number, updatedAt: string, repoCrawler: { __typename?: 'CrawlerMetrics', lastProcessedId: number, totalProcessed: number, totalCrawled: number, ratePerHour: number, ratePerMinute: number, ratePerSecond: number, requestCount: number, runCount: number }, userCrawler: { __typename?: 'CrawlerMetrics', lastProcessedId: number, totalProcessed: number, totalCrawled: number, ratePerHour: number, ratePerMinute: number, ratePerSecond: number, requestCount: number, runCount: number } }, errorRates: { __typename?: 'ErrorRates', coldPath: number } } };

export type GetRepoCrawlerMetricsQueryVariables = Exact<{
  timePeriodHours?: InputMaybe<Scalars['Int']['input']>;
}>;


export type GetRepoCrawlerMetricsQuery = { __typename?: 'Query', repoCrawler: { __typename?: 'CrawlerMetrics', lastProcessedId: number, totalProcessed: number, totalCrawled: number, ratePerHour: number, ratePerMinute: number, ratePerSecond: number, requestCount: number, runCount: number } };

export type GetUserCrawlerMetricsQueryVariables = Exact<{
  timePeriodHours?: InputMaybe<Scalars['Int']['input']>;
}>;


export type GetUserCrawlerMetricsQuery = { __typename?: 'Query', userCrawler: { __typename?: 'CrawlerMetrics', lastProcessedId: number, totalProcessed: number, totalCrawled: number, ratePerHour: number, ratePerMinute: number, ratePerSecond: number, requestCount: number, runCount: number } };

export type GetErrorRatesQueryVariables = Exact<{ [key: string]: never; }>;


export type GetErrorRatesQuery = { __typename?: 'Query', errorRates: { __typename?: 'ErrorRates', coldPath: number } };

export type OnCrawlerCompletedSubscriptionVariables = Exact<{
  crawlerType?: InputMaybe<Scalars['String']['input']>;
}>;


export type OnCrawlerCompletedSubscription = { __typename?: 'Subscription', onCrawlerCompleted?: { __typename?: 'CrawlerCompleted', crawlerType: string, startId: number, endId: number, itemsFetched: number, totalProcessed: number, completedAt: string } | null };


export const PublishCrawlerCompletedDocument = gql`
    mutation PublishCrawlerCompleted($input: CrawlerCompletedInput!) {
  publishCrawlerCompleted(input: $input) {
    crawlerType
    startId
    endId
    itemsFetched
    totalProcessed
    completedAt
  }
}
    `;

/**
 * __usePublishCrawlerCompletedMutation__
 *
 * To run a mutation, you first call `usePublishCrawlerCompletedMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `usePublishCrawlerCompletedMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [publishCrawlerCompletedMutation, { data, loading, error }] = usePublishCrawlerCompletedMutation({
 *   variables: {
 *      input: // value for 'input'
 *   },
 * });
 */
export function usePublishCrawlerCompletedMutation(baseOptions?: ApolloReactHooks.MutationHookOptions<PublishCrawlerCompletedMutation, PublishCrawlerCompletedMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useMutation<PublishCrawlerCompletedMutation, PublishCrawlerCompletedMutationVariables>(PublishCrawlerCompletedDocument, options);
      }
export type PublishCrawlerCompletedMutationHookResult = ReturnType<typeof usePublishCrawlerCompletedMutation>;
export type PublishCrawlerCompletedMutationResult = ApolloReactCommon.MutationResult<PublishCrawlerCompletedMutation>;
export type PublishCrawlerCompletedMutationOptions = ApolloReactCommon.MutationHookOptions<PublishCrawlerCompletedMutation, PublishCrawlerCompletedMutationVariables>;
export const GetPipelineStatusDocument = gql`
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
 * __useGetPipelineStatusQuery__
 *
 * To run a query within a React component, call `useGetPipelineStatusQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetPipelineStatusQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetPipelineStatusQuery({
 *   variables: {
 *   },
 * });
 */
export function useGetPipelineStatusQuery(baseOptions?: ApolloReactHooks.QueryHookOptions<GetPipelineStatusQuery, GetPipelineStatusQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useQuery<GetPipelineStatusQuery, GetPipelineStatusQueryVariables>(GetPipelineStatusDocument, options);
      }
export function useGetPipelineStatusLazyQuery(baseOptions?: ApolloReactHooks.LazyQueryHookOptions<GetPipelineStatusQuery, GetPipelineStatusQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return ApolloReactHooks.useLazyQuery<GetPipelineStatusQuery, GetPipelineStatusQueryVariables>(GetPipelineStatusDocument, options);
        }
export type GetPipelineStatusQueryHookResult = ReturnType<typeof useGetPipelineStatusQuery>;
export type GetPipelineStatusLazyQueryHookResult = ReturnType<typeof useGetPipelineStatusLazyQuery>;
export type GetPipelineStatusQueryResult = ApolloReactCommon.QueryResult<GetPipelineStatusQuery, GetPipelineStatusQueryVariables>;
export const GetRepoCrawlerMetricsDocument = gql`
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
 * __useGetRepoCrawlerMetricsQuery__
 *
 * To run a query within a React component, call `useGetRepoCrawlerMetricsQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetRepoCrawlerMetricsQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetRepoCrawlerMetricsQuery({
 *   variables: {
 *      timePeriodHours: // value for 'timePeriodHours'
 *   },
 * });
 */
export function useGetRepoCrawlerMetricsQuery(baseOptions?: ApolloReactHooks.QueryHookOptions<GetRepoCrawlerMetricsQuery, GetRepoCrawlerMetricsQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useQuery<GetRepoCrawlerMetricsQuery, GetRepoCrawlerMetricsQueryVariables>(GetRepoCrawlerMetricsDocument, options);
      }
export function useGetRepoCrawlerMetricsLazyQuery(baseOptions?: ApolloReactHooks.LazyQueryHookOptions<GetRepoCrawlerMetricsQuery, GetRepoCrawlerMetricsQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return ApolloReactHooks.useLazyQuery<GetRepoCrawlerMetricsQuery, GetRepoCrawlerMetricsQueryVariables>(GetRepoCrawlerMetricsDocument, options);
        }
export type GetRepoCrawlerMetricsQueryHookResult = ReturnType<typeof useGetRepoCrawlerMetricsQuery>;
export type GetRepoCrawlerMetricsLazyQueryHookResult = ReturnType<typeof useGetRepoCrawlerMetricsLazyQuery>;
export type GetRepoCrawlerMetricsQueryResult = ApolloReactCommon.QueryResult<GetRepoCrawlerMetricsQuery, GetRepoCrawlerMetricsQueryVariables>;
export const GetUserCrawlerMetricsDocument = gql`
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
 * __useGetUserCrawlerMetricsQuery__
 *
 * To run a query within a React component, call `useGetUserCrawlerMetricsQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetUserCrawlerMetricsQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetUserCrawlerMetricsQuery({
 *   variables: {
 *      timePeriodHours: // value for 'timePeriodHours'
 *   },
 * });
 */
export function useGetUserCrawlerMetricsQuery(baseOptions?: ApolloReactHooks.QueryHookOptions<GetUserCrawlerMetricsQuery, GetUserCrawlerMetricsQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useQuery<GetUserCrawlerMetricsQuery, GetUserCrawlerMetricsQueryVariables>(GetUserCrawlerMetricsDocument, options);
      }
export function useGetUserCrawlerMetricsLazyQuery(baseOptions?: ApolloReactHooks.LazyQueryHookOptions<GetUserCrawlerMetricsQuery, GetUserCrawlerMetricsQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return ApolloReactHooks.useLazyQuery<GetUserCrawlerMetricsQuery, GetUserCrawlerMetricsQueryVariables>(GetUserCrawlerMetricsDocument, options);
        }
export type GetUserCrawlerMetricsQueryHookResult = ReturnType<typeof useGetUserCrawlerMetricsQuery>;
export type GetUserCrawlerMetricsLazyQueryHookResult = ReturnType<typeof useGetUserCrawlerMetricsLazyQuery>;
export type GetUserCrawlerMetricsQueryResult = ApolloReactCommon.QueryResult<GetUserCrawlerMetricsQuery, GetUserCrawlerMetricsQueryVariables>;
export const GetErrorRatesDocument = gql`
    query GetErrorRates {
  errorRates {
    coldPath
  }
}
    `;

/**
 * __useGetErrorRatesQuery__
 *
 * To run a query within a React component, call `useGetErrorRatesQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetErrorRatesQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetErrorRatesQuery({
 *   variables: {
 *   },
 * });
 */
export function useGetErrorRatesQuery(baseOptions?: ApolloReactHooks.QueryHookOptions<GetErrorRatesQuery, GetErrorRatesQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useQuery<GetErrorRatesQuery, GetErrorRatesQueryVariables>(GetErrorRatesDocument, options);
      }
export function useGetErrorRatesLazyQuery(baseOptions?: ApolloReactHooks.LazyQueryHookOptions<GetErrorRatesQuery, GetErrorRatesQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return ApolloReactHooks.useLazyQuery<GetErrorRatesQuery, GetErrorRatesQueryVariables>(GetErrorRatesDocument, options);
        }
export type GetErrorRatesQueryHookResult = ReturnType<typeof useGetErrorRatesQuery>;
export type GetErrorRatesLazyQueryHookResult = ReturnType<typeof useGetErrorRatesLazyQuery>;
export type GetErrorRatesQueryResult = ApolloReactCommon.QueryResult<GetErrorRatesQuery, GetErrorRatesQueryVariables>;
export const OnCrawlerCompletedDocument = gql`
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

/**
 * __useOnCrawlerCompletedSubscription__
 *
 * To run a query within a React component, call `useOnCrawlerCompletedSubscription` and pass it any options that fit your needs.
 * When your component renders, `useOnCrawlerCompletedSubscription` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the subscription, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useOnCrawlerCompletedSubscription({
 *   variables: {
 *      crawlerType: // value for 'crawlerType'
 *   },
 * });
 */
export function useOnCrawlerCompletedSubscription(baseOptions?: ApolloReactHooks.SubscriptionHookOptions<OnCrawlerCompletedSubscription, OnCrawlerCompletedSubscriptionVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useSubscription<OnCrawlerCompletedSubscription, OnCrawlerCompletedSubscriptionVariables>(OnCrawlerCompletedDocument, options);
      }
export type OnCrawlerCompletedSubscriptionHookResult = ReturnType<typeof useOnCrawlerCompletedSubscription>;
export type OnCrawlerCompletedSubscriptionResult = ApolloReactCommon.SubscriptionResult<OnCrawlerCompletedSubscription>;