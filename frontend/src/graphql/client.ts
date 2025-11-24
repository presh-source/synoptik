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
    const definition = query.definitions[0];

    // Check if this is a subscription
    const isSubscription =
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription';

    if (isSubscription) {
      const cleanVariables = variables || {};

      console.log('[Amplify Subscription] Starting subscription:', {
        query: queryString,
        variables: cleanVariables,
      });

      // Ensure API key is present
      if (!import.meta.env.VITE_DASHBOARD_APPSYNC_API_KEY) {
        console.error('[Amplify Subscription] Missing API Key');
        observer.error(new Error('Missing API Key'));
        return () => { };
      }

      // Use Amplify's native subscription (WebSocket)
      // TypeScript doesn't know that subscriptions return an Observable, so we cast to any
      const subscription = (graphqlClient.graphql({
        query: queryString,
        variables: cleanVariables,
        authMode: 'apiKey',
      }) as any).subscribe({
        next: (response: any) => {
          console.log('[Amplify Subscription] Received data:', response);
          try {
            // Amplify returns the response in different formats
            // Handle both { data } and { value: { data } } formats
            const result = response.value || response;
            const data = result.data || result;
            const errors = result.errors;

            observer.next({
              data: data || {},
              errors: errors || undefined,
            });
          } catch (err) {
            console.error('[Amplify Subscription] Error processing response:', err, response);
            observer.error(err);
          }
        },
        error: (error: any) => {
          console.error('[Amplify Subscription] Subscription error:', error);
          // Check for UnconventionalError and try to extract meaningful message
          if (error.message === 'An error of unexpected shape occurred.') {
            console.warn('[Amplify Subscription] Encountered UnconventionalError. This often means the subscription handshake failed or the data shape is mismatched.');
          }
          observer.error(error);
        },
        complete: () => {
          console.log('[Amplify Subscription] Subscription completed');
          observer.complete();
        },
      });

      // Return cleanup function
      return () => {
        subscription.unsubscribe();
      };
    } else {
      // Use regular graphql() for queries and mutations
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
    }
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
