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

export type CrawlerCompleted = {
  __typename?: 'CrawlerCompleted';
  entity?: Maybe<Scalars['String']['output']>;
  itemsFetched?: Maybe<Scalars['Int']['output']>;
  lastProcessedId?: Maybe<Scalars['Int']['output']>;
  organisation?: Maybe<Scalars['String']['output']>;
  totalProcessed?: Maybe<Scalars['Int']['output']>;
  updatedAt?: Maybe<Scalars['AWSDateTime']['output']>;
};

export type CrawlerCompletedInput = {
  entity: Scalars['String']['input'];
  itemsFetched: Scalars['Int']['input'];
  lastProcessedId: Scalars['Int']['input'];
  organisation: Scalars['String']['input'];
  totalProcessed: Scalars['Int']['input'];
  updatedAt: Scalars['AWSDateTime']['input'];
};

export type Mutation = {
  __typename?: 'Mutation';
  publishCrawlerCompleted: CrawlerCompleted;
};


export type MutationPublishCrawlerCompletedArgs = {
  input: CrawlerCompletedInput;
};

export type Query = {
  __typename?: 'Query';
  getCrawlerState?: Maybe<CrawlerCompleted>;
};


export type QueryGetCrawlerStateArgs = {
  entity: Scalars['String']['input'];
  organisation: Scalars['String']['input'];
};

export type Subscription = {
  __typename?: 'Subscription';
  onCrawlerCompleted?: Maybe<CrawlerCompleted>;
};


export type SubscriptionOnCrawlerCompletedArgs = {
  entity?: InputMaybe<Scalars['String']['input']>;
  organisation?: InputMaybe<Scalars['String']['input']>;
};

export type PublishCrawlerCompletedMutationVariables = Exact<{
  input: CrawlerCompletedInput;
}>;


export type PublishCrawlerCompletedMutation = { __typename?: 'Mutation', publishCrawlerCompleted: { __typename?: 'CrawlerCompleted', organisation?: string | null, entity?: string | null, itemsFetched?: number | null, lastProcessedId?: number | null, totalProcessed?: number | null, updatedAt?: string | null } };

export type GetCrawlerStateQueryVariables = Exact<{
  organisation: Scalars['String']['input'];
  entity: Scalars['String']['input'];
}>;


export type GetCrawlerStateQuery = { __typename?: 'Query', getCrawlerState?: { __typename?: 'CrawlerCompleted', lastProcessedId?: number | null, totalProcessed?: number | null, itemsFetched?: number | null, updatedAt?: string | null } | null };

export type OnCrawlerCompletedSubscriptionVariables = Exact<{
  organisation?: InputMaybe<Scalars['String']['input']>;
  entity?: InputMaybe<Scalars['String']['input']>;
}>;


export type OnCrawlerCompletedSubscription = { __typename?: 'Subscription', onCrawlerCompleted?: { __typename?: 'CrawlerCompleted', organisation?: string | null, entity?: string | null, itemsFetched?: number | null, lastProcessedId?: number | null, totalProcessed?: number | null, updatedAt?: string | null } | null };


export const PublishCrawlerCompletedDocument = gql`
    mutation PublishCrawlerCompleted($input: CrawlerCompletedInput!) {
  publishCrawlerCompleted(input: $input) {
    organisation
    entity
    itemsFetched
    lastProcessedId
    totalProcessed
    updatedAt
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
export const GetCrawlerStateDocument = gql`
    query GetCrawlerState($organisation: String!, $entity: String!) {
  getCrawlerState(organisation: $organisation, entity: $entity) {
    lastProcessedId
    totalProcessed
    itemsFetched
    updatedAt
  }
}
    `;

/**
 * __useGetCrawlerStateQuery__
 *
 * To run a query within a React component, call `useGetCrawlerStateQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetCrawlerStateQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetCrawlerStateQuery({
 *   variables: {
 *      organisation: // value for 'organisation'
 *      entity: // value for 'entity'
 *   },
 * });
 */
export function useGetCrawlerStateQuery(baseOptions: ApolloReactHooks.QueryHookOptions<GetCrawlerStateQuery, GetCrawlerStateQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useQuery<GetCrawlerStateQuery, GetCrawlerStateQueryVariables>(GetCrawlerStateDocument, options);
      }
export function useGetCrawlerStateLazyQuery(baseOptions?: ApolloReactHooks.LazyQueryHookOptions<GetCrawlerStateQuery, GetCrawlerStateQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return ApolloReactHooks.useLazyQuery<GetCrawlerStateQuery, GetCrawlerStateQueryVariables>(GetCrawlerStateDocument, options);
        }
export type GetCrawlerStateQueryHookResult = ReturnType<typeof useGetCrawlerStateQuery>;
export type GetCrawlerStateLazyQueryHookResult = ReturnType<typeof useGetCrawlerStateLazyQuery>;
export type GetCrawlerStateQueryResult = ApolloReactCommon.QueryResult<GetCrawlerStateQuery, GetCrawlerStateQueryVariables>;
export const OnCrawlerCompletedDocument = gql`
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
 *      organisation: // value for 'organisation'
 *      entity: // value for 'entity'
 *   },
 * });
 */
export function useOnCrawlerCompletedSubscription(baseOptions?: ApolloReactHooks.SubscriptionHookOptions<OnCrawlerCompletedSubscription, OnCrawlerCompletedSubscriptionVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return ApolloReactHooks.useSubscription<OnCrawlerCompletedSubscription, OnCrawlerCompletedSubscriptionVariables>(OnCrawlerCompletedDocument, options);
      }
export type OnCrawlerCompletedSubscriptionHookResult = ReturnType<typeof useOnCrawlerCompletedSubscription>;
export type OnCrawlerCompletedSubscriptionResult = ApolloReactCommon.SubscriptionResult<OnCrawlerCompletedSubscription>;