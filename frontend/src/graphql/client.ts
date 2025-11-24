import { ApolloClient, InMemoryCache, HttpLink, split } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { getMainDefinition } from '@apollo/client/utilities';
import { createClient } from 'graphql-ws';

// AppSync endpoint configuration from environment variables
const DASHBOARD_APPSYNC_API_URL = import.meta.env.VITE_DASHBOARD_APPSYNC_API_URL;
const DASHBOARD_APPSYNC_API_KEY = import.meta.env.VITE_DASHBOARD_APPSYNC_API_KEY;
const DASHBOARD_APPSYNC_REALTIME_URL = import.meta.env.VITE_DASHBOARD_APPSYNC_REALTIME_URL;

// HTTP link for queries and mutations
const httpLink = new HttpLink({
  uri: DASHBOARD_APPSYNC_API_URL,
  headers: {
    'x-api-key': DASHBOARD_APPSYNC_API_KEY,
  },
});

// WebSocket link for subscriptions
const wsLink = new GraphQLWsLink(
  createClient({
    url: DASHBOARD_APPSYNC_REALTIME_URL,
    connectionParams: {
      'x-api-key': DASHBOARD_APPSYNC_API_KEY,
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
