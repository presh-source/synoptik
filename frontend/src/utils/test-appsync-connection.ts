/**
 * AppSync Connection Test Utility
 * Run in browser console: testAppSyncConnection()
 */

import { generateClient } from 'aws-amplify/api';

export const testAppSyncConnection = async () => {
  console.log('🔍 Testing AppSync Connection...');
  console.log('📋 Environment Variables:');
  console.log('  VITE_DASHBOARD_APPSYNC_API_URL:', import.meta.env.VITE_DASHBOARD_APPSYNC_API_URL);
  console.log('  VITE_DASHBOARD_APPSYNC_API_KEY:', import.meta.env.VITE_DASHBOARD_APPSYNC_API_KEY ? '✅ Set' : '❌ Missing');
  console.log('  VITE_AWS_REGION:', import.meta.env.VITE_AWS_REGION);

  const client = generateClient();

  // Test 1: Simple Query
  console.log('\n📤 Test 1: Executing pipelineStatus query...');
  try {
    const result: any = await client.graphql({
      query: `
        query GetPipelineStatus {
          pipelineStatus {
            coldPath {
              lastProcessedId
              totalProcessed
            }
          }
        }
      `,
    });
    console.log('✅ Query successful:', result);
  } catch (error) {
    console.error('❌ Query failed:', error);
  }

  // Test 2: Subscription
  console.log('\n📡 Test 2: Testing subscription...');
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const subscription = (client.graphql({
      query: `
        subscription OnCrawlerCompleted {
          onCrawlerCompleted {
            crawlerType
            itemsFetched
            success
          }
        }
      `,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    }) as any).subscribe({
      next: (data: unknown) => {
        console.log('📨 Subscription data received:', data);
      },
      error: (error: unknown) => {
        console.error('❌ Subscription error:', error);
        console.error('Error details:', JSON.stringify(error, null, 2));
      },
      complete: () => {
        console.log('✅ Subscription completed');
      },
    });

    console.log('✅ Subscription started successfully');
    console.log('💡 Subscription will listen for events. Unsubscribe with:');
    console.log('   subscription.unsubscribe()');

    // Store in window for manual cleanup
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (window as any).testSubscription = subscription;

    // Auto-unsubscribe after 30 seconds
    setTimeout(() => {
      console.log('⏱️  30 seconds elapsed, unsubscribing...');
      subscription.unsubscribe();
    }, 30000);

  } catch (error) {
    console.error('❌ Subscription setup failed:', error);
  }
};

// Make it available globally
if (typeof window !== 'undefined') {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (window as any).testAppSyncConnection = testAppSyncConnection;
  console.log('✅ AppSync connection test loaded!');
  console.log('💡 Run: testAppSyncConnection()');
}
