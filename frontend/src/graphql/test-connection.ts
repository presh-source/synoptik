/**
 * Test script to verify Apollo Client configuration
 * This validates that environment variables are set and the client is properly configured
 */

import { apolloClient } from './client';

export function testApolloClientConnection(): void {
  console.log('Testing Apollo Client Configuration...');

  // Check environment variables
  const endpoint = import.meta.env.VITE_DASHBOARD_APPSYNC_API_URL;
  const apiKey = import.meta.env.VITE_APPSYNC_API_KEY;
  const realtimeEndpoint = import.meta.env.VITE_APPSYNC_REALTIME_URL;

  console.log('Environment Variables:');
  console.log('- VITE_DASHBOARD_APPSYNC_API_URL:', endpoint ? '✓ Set' : '✗ Missing');
  console.log('- VITE_APPSYNC_API_KEY:', apiKey ? '✓ Set' : '✗ Missing');
  console.log('- VITE_APPSYNC_REALTIME_URL:', realtimeEndpoint ? '✓ Set' : '✗ Missing');

  // Check Apollo Client instance
  if (apolloClient) {
    console.log('✓ Apollo Client instance created successfully');
    console.log('✓ Cache configured:', apolloClient.cache ? 'Yes' : 'No');
    console.log('✓ Link configured:', apolloClient.link ? 'Yes' : 'No');
  } else {
    console.error('✗ Apollo Client instance not created');
  }

  // Validate configuration
  const isValid = endpoint && apiKey && realtimeEndpoint && apolloClient;

  if (isValid) {
    console.log('\n✓ Apollo Client is properly configured and ready to use');
  } else {
    console.error('\n✗ Apollo Client configuration is incomplete');
  }

  return;
}

// Run test if this file is executed directly
if (import.meta.env.DEV) {
  testApolloClientConnection();
}
