/**
 * Subscription Testing Utility
 * 
 * This utility helps test and debug GraphQL subscriptions in the browser console.
 * It provides functions to monitor subscription events and verify the end-to-end flow.
 * 
 * Usage in browser console:
 * 1. Open DevTools Console
 * 2. Run: window.testSubscription.start()
 * 3. Trigger a crawler
 * 4. Watch for events in console
 * 5. Run: window.testSubscription.stop()
 */

import { apolloClient } from '../graphql/client'
import { ON_CRAWLER_COMPLETED } from '../graphql/subscriptions'
import {
  OnCrawlerCompletedSubscription,
  CrawlerCompleted,
} from '../graphql/generated/types'

class SubscriptionTester {
  private subscription: any = null
  private events: CrawlerCompleted[] = []
  private startTime: number = 0

  /**
   * Start monitoring subscription events
   */
  start(crawlerType?: string) {
    if (this.subscription) {
      console.warn('⚠️ Subscription already active. Call stop() first.')
      return
    }

    this.events = []
    this.startTime = Date.now()

    console.log('🚀 Starting subscription monitoring...')
    if (crawlerType) {
      console.log(`📡 Filtering for crawler type: ${crawlerType}`)
    } else {
      console.log('📡 Listening to all crawler events')
    }

    this.subscription = apolloClient
      .subscribe<OnCrawlerCompletedSubscription>({
        query: ON_CRAWLER_COMPLETED,
        variables: crawlerType ? { crawlerType } : {},
      })
      .subscribe({
        next: ({ data }) => {
          const event = data?.onCrawlerCompleted
          if (event) {
            this.handleEvent(event)
          }
        },
        error: (error) => {
          console.error('❌ Subscription error:', error)
        },
        complete: () => {
          console.log('✅ Subscription completed')
        },
      })

    console.log('✅ Subscription active. Waiting for events...')
    console.log('💡 Trigger a crawler to see events appear here')
  }

  /**
   * Stop monitoring subscription events
   */
  stop() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
      console.log('🛑 Subscription stopped')
      this.printSummary()
    } else {
      console.warn('⚠️ No active subscription to stop')
    }
  }

  /**
   * Handle incoming subscription event
   */
  private handleEvent(event: CrawlerCompleted) {
    const latency = Date.now() - this.startTime

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📨 Crawler Event Received!')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('🔹 Crawler Type:', event.crawlerType)
    console.log('🔹 Items Fetched:', event.itemsFetched.toLocaleString())
    console.log('🔹 Total Processed:', event.totalProcessed.toLocaleString())
    console.log('🔹 Start ID:', event.startId)
    console.log('🔹 End ID:', event.endId)
    console.log('🔹 Completed At:', new Date(event.updatedAt).toLocaleString())

    console.log('🔹 Latency:', `${latency}ms`)
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    // Store event
    this.events.push(event)

    // Update start time for next event
    this.startTime = Date.now()
  }

  /**
   * Print summary of received events
   */
  private printSummary() {
    console.log('\n📊 Subscription Summary')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('Total Events Received:', this.events.length)

    if (this.events.length > 0) {
      const repoEvents = this.events.filter(e => e.crawlerType === 'repo')
      const userEvents = this.events.filter(e => e.crawlerType === 'user')

      console.log('  - Repo Crawler Events:', repoEvents.length)
      console.log('  - User Crawler Events:', userEvents.length)

      console.log('\nEvent Details:')
      this.events.forEach((event, index) => {
        console.log(`  ${index + 1}. ${event.crawlerType} - ${event.itemsFetched} items`)
      })
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
  }

  /**
   * Get all received events
   */
  getEvents(): CrawlerCompleted[] {
    return [...this.events]
  }

  /**
   * Clear event history
   */
  clearEvents() {
    this.events = []
    console.log('🗑️ Event history cleared')
  }

  /**
   * Check subscription status
   */
  status() {
    if (this.subscription) {
      console.log('✅ Subscription is ACTIVE')
      console.log('📊 Events received:', this.events.length)
    } else {
      console.log('⭕ Subscription is INACTIVE')
      console.log('💡 Run testSubscription.start() to begin monitoring')
    }
  }
}

// Create singleton instance
const subscriptionTester = new SubscriptionTester()

// Expose to window for browser console access
if (typeof window !== 'undefined') {
  (window as any).testSubscription = {
    start: (crawlerType?: string) => subscriptionTester.start(crawlerType),
    stop: () => subscriptionTester.stop(),
    status: () => subscriptionTester.status(),
    getEvents: () => subscriptionTester.getEvents(),
    clearEvents: () => subscriptionTester.clearEvents(),
    help: () => {
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('📚 Subscription Testing Utility - Help')
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('\nAvailable Commands:')
      console.log('  testSubscription.start()           - Start monitoring all events')
      console.log('  testSubscription.start("repo")     - Monitor only repo crawler events')
      console.log('  testSubscription.start("user")     - Monitor only user crawler events')
      console.log('  testSubscription.stop()            - Stop monitoring and show summary')
      console.log('  testSubscription.status()          - Check subscription status')
      console.log('  testSubscription.getEvents()       - Get all received events')
      console.log('  testSubscription.clearEvents()     - Clear event history')
      console.log('  testSubscription.help()            - Show this help message')
      console.log('\nExample Workflow:')
      console.log('  1. testSubscription.start()')
      console.log('  2. Trigger a crawler (via AWS CLI or EventBridge)')
      console.log('  3. Watch for events in console')
      console.log('  4. testSubscription.stop()')
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    },
  }

  console.log('✅ Subscription testing utility loaded!')
  console.log('💡 Run testSubscription.help() for usage instructions')
}

export default subscriptionTester
