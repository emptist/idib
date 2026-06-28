// idib Gateway: bars → indicators → fractal → signals → dashboard
// Usage: node gateway/index.mjs

import { IBGateway } from './ib.mjs'
import { SSEServer } from './sse.mjs'
import { computeFractal } from '../ffi/idib-ffi.mjs'

const IB_HOST = process.env.IB_HOST || '127.0.0.1'
const IB_PORT = parseInt(process.env.IB_PORT || '7497')
const SSE_PORT = parseInt(process.env.SSE_PORT || '3000')

const DURATIONS = {
  '1m': '1 D', '5m': '1 D', '15m': '2 D', '30m': '5 D',
  '1h': '1 W', '4h': '1 M', '1d': '1 M', '1w': '1 Y',
}

const INTERVAL_KEYS = {
  '1 month': '1d', '1 day': '1d', '1 week': '1w',
  '1h': '1h', '4h': '4h', '1m': '1m', '5m': '5m',
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

  sse.onRequest = async (symbol, intervals) => {
    if (!ibConnected) {
      sse.broadcast('system', { error: 'IB not connected' })
      return
    }

    for (const intervalLabel of intervals) {
      const duration = DURATIONS[intervalLabel] || '1 W'
      const intervalKey = INTERVAL_KEYS[intervalLabel] || '1d'
      console.log(`Fetch: ${symbol} [${intervalLabel}] ${duration}`)

      try {
        const data = await ib.reqHistoricalData({
          symbol, duration, barSize: intervalLabel, whatToShow: 'TRADES',
        })

        if (data.ok && data.bars.length > 0) {
          // Full pipeline: indicators + fractal in one O(N) pass
          const { chartResults, fractal } = computeFractal(intervalKey, data.bars)

          // Merge indicators into bar data for dashboard
          const chartBars = data.bars.map((bar, i) => ({
            bar,
            ...(chartResults[i] || {}),
          }))

          sse.broadcast(symbol, {
            interval: intervalLabel,
            chartBars,
            leaves: fractal.leaves,
            branches: fractal.branches,
            bullMarket: fractal.bullMarket,
            timestamp: new Date().toISOString(),
          })
          console.log(`  ${symbol} [${intervalLabel}]: ${data.bars.length} bars, ${fractal.leaves.length} leaves, bull=${fractal.bullMarket}`)
        }
      } catch (err) {
        console.error(`  ${symbol} [${intervalLabel}]: ${err.message}`)
        sse.broadcast(symbol, { interval: intervalLabel, error: err.message })
      }
    }
  }

  console.log('Gateway ready. Waiting for requests...')
}

main().catch(console.error)
