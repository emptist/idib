// idib Gateway: one symbol, multiple intervals
// Usage: node gateway/index.mjs

import { IBGateway } from './ib.mjs'
import { SSEServer } from './sse.mjs'
import { detectFractal } from '../ffi/idib-ffi.mjs'

const SYMBOL = process.env.SYMBOL || 'SPY'
const INTERVALS = process.env.INTERVALS?.split(',') || ['1 hour', '1 day']
const IB_HOST = process.env.IB_HOST || '127.0.0.1'
const IB_PORT = parseInt(process.env.IB_PORT || '7497')
const SSE_PORT = parseInt(process.env.SSE_PORT || '3000')

const DURATIONS = {
  '1 min':  '1 D',
  '5 min':  '1 D',
  '15 min': '2 D',
  '30 min': '5 D',
  '1 hour': '1 W',
  '1 day':  '1 M',
  '1 week': '1 Y',
}

const INTERVAL_LABELS = {
  '1 min': '1m', '5 min': '5m', '15 min': '15m', '30 min': '30m',
  '1 hour': '1h', '1 day': '1d', '1 week': '1w',
}

async function main() {
  console.log('=== idib Gateway ===')
  console.log(`Symbol: ${SYMBOL}`)
  console.log(`Intervals: ${INTERVALS.join(', ')}`)
  console.log(`IB: ${IB_HOST}:${IB_PORT}`)
  console.log(`SSE: port ${SSE_PORT}`)

  const sse = new SSEServer(SSE_PORT)
  await sse.start()

  const ib = new IBGateway(IB_HOST, IB_PORT, 1)
  try {
    await ib.connect()
  } catch (err) {
    console.error('IB:', err.message)
    console.log('Offline mode')
  }

  // Fetch each interval
  for (const interval of INTERVALS) {
    const duration = DURATIONS[interval] || '1 W'
    const label = INTERVAL_LABELS[interval] || interval
    console.log(`\n${SYMBOL} [${interval}] — ${duration}...`)

    try {
      const data = await ib.reqHistoricalData({
        symbol: SYMBOL,
        duration,
        barSize: interval,
        whatToShow: 'TRADES',
      })

      if (data.ok && data.bars.length > 0) {
        console.log(`  ${data.bars.length} bars`)

        const bars = data.bars.map((b, i) => ({ index: i, value: b.close }))
        const fractal = detectFractal(bars, { interval: label })

        console.log(`  ${fractal.leaves.length} leaves, ${fractal.branches.length} branches`)

        sse.broadcast(SYMBOL, {
          interval: label,
          chartBars: data.bars,
          leaves: fractal.leaves,
          branches: fractal.branches,
          timestamp: new Date().toISOString(),
        })
      }
    } catch (err) {
      console.error(`  Error: ${err.message}`)
    }
  }

  // Real-time on first interval
  const rtInterval = INTERVALS[0]
  const rtLabel = INTERVAL_LABELS[rtInterval] || rtInterval
  console.log(`\nReal-time ${SYMBOL} [${rtInterval}]...`)

  ib.reqRealtimeBars({
    symbol: SYMBOL,
    barSize: 5,
    onBar: (bar) => {
      sse.broadcast(SYMBOL, {
        interval: rtLabel,
        realtime: bar,
        timestamp: new Date().toISOString(),
      })
    }
  })

  console.log('\nGateway running.')
}

main().catch(console.error)
