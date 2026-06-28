// idib Gateway: dynamic symbol + interval via SSE control channel
// Usage: node gateway/index.mjs

import { IBGateway } from './ib.mjs'
import { SSEServer } from './sse.mjs'
import { detectFractal } from '../ffi/idib-ffi.mjs'

const IB_HOST = process.env.IB_HOST || '127.0.0.1'
const IB_PORT = parseInt(process.env.IB_PORT || '7497')
const SSE_PORT = parseInt(process.env.SSE_PORT || '3000')

const DURATIONS = {
  '1m': '1 D', '5m': '1 D', '15m': '2 D', '30m': '5 D',
  '1h': '1 W', '4h': '1 M', '1d': '1 M', '1w': '1 Y',
}

async function main() {
  console.log('=== idib Gateway ===')
  console.log(`IB: ${IB_HOST}:${IB_PORT} | SSE: ${SSE_PORT}`)

  const sse = new SSEServer(SSE_PORT)
  await sse.start()

  const ib = new IBGateway(IB_HOST, IB_PORT, 1)
  let ibConnected = false
  try {
    await ib.connect()
    ibConnected = true
  } catch (err) {
    console.error('IB:', err.message, '— offline mode')
  }

  // Handle requests from dashboard via SSE POST or query
  sse.onRequest = async (symbol, intervals) => {
    if (!ibConnected) {
      sse.broadcast('system', { error: 'IB not connected' })
      return
    }

    for (const interval of intervals) {
      const duration = DURATIONS[interval] || '1 W'
      console.log(`Fetch: ${symbol} [${interval}] ${duration}`)

      try {
        const data = await ib.reqHistoricalData({
          symbol, duration, barSize: interval, whatToShow: 'TRADES',
        })

        if (data.ok && data.bars.length > 0) {
          const bars = data.bars.map((b, i) => ({ index: i, value: b.close }))
          const fractal = detectFractal(bars, { interval })

          sse.broadcast(symbol, {
            interval,
            chartBars: data.bars,
            leaves: fractal.leaves,
            branches: fractal.branches,
            timestamp: new Date().toISOString(),
          })
          console.log(`  ${symbol} [${interval}]: ${data.bars.length} bars, ${fractal.leaves.length} leaves`)
        }
      } catch (err) {
        console.error(`  ${symbol} [${interval}]: ${err.message}`)
        sse.broadcast(symbol, { interval, error: err.message })
      }
    }
  }

  console.log('Gateway ready. Waiting for requests...')
}

main().catch(console.error)
