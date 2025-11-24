import { Amplify } from 'aws-amplify';
import { generateClient } from 'aws-amplify/api';

// AppSync endpoint configuration from environment variables
const DASHBOARD_APPSYNC_API_URL = import.meta.env.VITE_DASHBOARD_APPSYNC_API_URL;
const DASHBOARD_APPSYNC_API_KEY = import.meta.env.VITE_DASHBOARD_APPSYNC_API_KEY;
const AWS_REGION = import.meta.env.VITE_AWS_REGION || 'us-east-1';

// Configure Amplify with AppSync
Amplify.configure({
  API: {
    GraphQL: {
      endpoint: DASHBOARD_APPSYNC_API_URL,
      region: AWS_REGION,
      defaultAuthMode: 'apiKey',
      apiKey: DASHBOARD_APPSYNC_API_KEY,
    },
  },
});

// Create the GraphQL client
// This client supports queries, mutations, and subscriptions (WebSocket)
export const graphqlClient = generateClient();

// For backwards compatibility with Apollo Client hooks, you can still use Apollo
// But route it through Amplify
import { ApolloClient, InMemoryCache, ApolloLink, Observable } from '@apollo/client';
import { print } from 'graphql';

// Custom Apollo Link that uses Amplify under the hood
const amplifyLink = new ApolloLink((operation) => {
  return new Observable((observer) => {
    const { query, variables } = operation;
    const queryString = print(query);

    // Use Amplify's graphqlClient to execute
    (async () => {
      try {
        const result: any = await graphqlClient.graphql({
          query: queryString,
          variables,
        });

        observer.next({
          data: result.data || {},
          errors: result.errors || undefined,
        });
        observer.complete();
      } catch (error) {
        observer.error(error);
      }
    })();
  });
});

// Apollo Client for components that use Apollo hooks
export const apolloClient = new ApolloClient({
  link: amplifyLink,
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
