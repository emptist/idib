// idib Gateway: ties together IB connection, indicator computation, and SSE streaming
// Usage: node gateway/index.mjs

import { IBGateway } from './ib.mjs'
import { SSEServer } from './sse.mjs'
import { detectFractal } from '../ffi/idib-ffi.mjs'

const SYMBOLS = process.env.SYMBOLS?.split(',') || ['SPY']
const IB_HOST = process.env.IB_HOST || '127.0.0.1'
const IB_PORT = parseInt(process.env.IB_PORT || '7497')
const SSE_PORT = parseInt(process.env.SSE_PORT || '3000')

async function main() {
  console.log('=== idib Gateway ===')
  console.log(`Symbols: ${SYMBOLS.join(', ')}`)
  console.log(`IB: ${IB_HOST}:${IB_PORT}`)
  console.log(`SSE: port ${SSE_PORT}`)

  // Start SSE server
  const sse = new SSEServer(SSE_PORT)
  await sse.start()

  // Connect to IB
  const ib = new IBGateway(IB_HOST, IB_PORT, 1)
  try {
    await ib.connect()
  } catch (err) {
    console.error('Failed to connect to IB:', err.message)
    console.log('Running in offline mode (no IB connection)')
  }

  // Fetch historical data for each symbol
  for (const symbol of SYMBOLS) {
    console.log(`\nFetching ${symbol}...`)
    try {
      const data = await ib.reqHistoricalData({
        symbol,
        duration: '1 D',
        barSize: '1 hour',
        whatToShow: 'TRADES'
      })

      if (data.ok && data.bars.length > 0) {
        console.log(`  Got ${data.bars.length} bars`)

        // Run fractal detection
        const bars = data.bars.map((b, i) => ({ index: i, value: b.close }))
        const fractal = detectFractal(bars)

        console.log(`  Leaves: ${fractal.leaves.length}`)
        console.log(`  Branches: ${fractal.branches.length}`)

        // Broadcast to SSE clients
        sse.broadcast(symbol, {
          bars: data.bars,
          leaves: fractal.leaves,
          branches: fractal.branches,
          timestamp: new Date().toISOString()
        })
      }
    } catch (err) {
      console.error(`  Error fetching ${symbol}:`, err.message)
    }
  }

  // Subscribe to real-time bars for first symbol
  if (SYMBOLS.length > 0) {
    const symbol = SYMBOLS[0]
    console.log(`\nSubscribing to real-time ${symbol}...`)
    ib.reqRealtimeBars({
      symbol,
      barSize: 5,
      onBar: (bar) => {
        console.log(`  RT: ${symbol} C:${bar.close}`)
        sse.broadcast(symbol, {
          realtime: bar,
          timestamp: new Date().toISOString()
        })
      }
    })
  }

  console.log('\nGateway running. Press Ctrl+C to stop.')
}

main().catch(console.error)
