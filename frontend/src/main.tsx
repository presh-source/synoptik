import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ApolloProvider } from '@apollo/client/react'
import { CssBaseline, ThemeProvider } from '@mui/material'
import App from './App'
import theme from './theme'
import { initSentry } from './config/sentry'
import { apolloClient } from './graphql/client'
import { testApolloClientConnection } from './graphql/test-connection'
import './utils/test-subscription' // Load subscription testing utility for browser console

// Initialize Sentry for error tracking in production
initSentry()

// Test Apollo Client connection in development mode
if (import.meta.env.DEV) {
  testApolloClientConnection()
}

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 30000,
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ApolloProvider client={apolloClient}>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider theme={theme}>
          <CssBaseline />
          <App />
        </ThemeProvider>
      </QueryClientProvider>
    </ApolloProvider>
  </React.StrictMode>,
)
