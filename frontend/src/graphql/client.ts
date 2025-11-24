import { ApolloClient, InMemoryCache, HttpLink, split } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { getMainDefinition } from '@apollo/client/utilities';
import { createClient } from 'graphql-ws';

// AppSync endpoint configuration from environment variables
const APPSYNC_ENDPOINT = import.meta.env.VITE_dashboard_appsync_api_url;
const APPSYNC_API_KEY = import.meta.env.VITE_APPSYNC_API_KEY;
const appsync_realtime_url = import.meta.env.VITE_APPSYNC_REALTIME_URL;

// HTTP link for queries and mutations
const httpLink = new HttpLink({
  uri: APPSYNC_ENDPOINT,
  headers: {
    'x-api-key': APPSYNC_API_KEY,
  },
});

// WebSocket link for subscriptions
const wsLink = new GraphQLWsLink(
  createClient({
    url: appsync_realtime_url,
    connectionParams: {
      'x-api-key': APPSYNC_API_KEY,
    },
    retryAttempts: 5,
    shouldRetry: () => true,
  })
);

// Split based on operation type
// Subscriptions go through WebSocket, queries and mutations go through HTTP
const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query);
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    );
  },
  wsLink,
  httpLink
);

// Create Apollo Client with split link and cache configuration
export const apolloClient = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          pipelineStatus: {
            merge: true,
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
  },
});
