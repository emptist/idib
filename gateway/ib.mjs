// IB Gateway bridge: connects to IB TWS/Gateway via @stoqey/ib
// Provides historical data fetching and real-time bar streaming

import { IBApi, EventName } from '@stoqey/ib'

export class IBGateway {
  constructor(host = '127.0.0.1', port = 7497, clientId = 1) {
    this.host = host
    this.port = port
    this.clientId = clientId
    this.api = null
    this.connected = false
    this.accounts = []
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.api = new IBApi({
        host: this.host,
        port: this.port,
        clientId: this.clientId
      })

      const onConnected = () => {
        console.log(`IB: connected to ${this.host}:${this.port}`)
      }

      const onError = (err) => {
        console.error('IB: error:', err)
        if (!this.connected) reject(err)
      }

      const onAccounts = (acctList) => {
        this.accounts = acctList.split(',').map(s => s.trim())
        console.log(`IB: accounts: ${this.accounts.join(', ')}`)
        if (!this.connected) {
          this.connected = true
          resolve({ ok: true, accounts: this.accounts })
        }
      }

      this.api.once(EventName.connected, onConnected)
      this.api.on(EventName.error, onError)
      this.api.on(EventName.managedAccounts, onAccounts)

      this.api.connect()
    })
  }

  disconnect() {
    try {
      this.api?.disconnect()
      this.connected = false
      console.log('IB: disconnected')
    } catch (_) {}
  }

  // Fetch historical bars
  reqHistoricalData({
    symbol,
    exchange = 'SMART',
    currency = 'USD',
    duration = '1 D',
    barSize = '1 hour',
    whatToShow = 'TRADES',
    useRth = true
  }) {
    return new Promise((resolve) => {
      const bars = []
      let resolved = false
      const reqId = Math.floor(Math.random() * 100000)

      const onBar = (recvReqId, time, open, high, low, close, volume, count, wap) => {
        if (recvReqId !== reqId) return
        if (typeof time === 'string' && time.startsWith('finished')) {
          if (!resolved) {
            resolved = true
            resolve({ ok: true, bars })
          }
          return
        }
        bars.push({
          date: time,
          open: parseFloat(open),
          high: parseFloat(high),
          low: parseFloat(low),
          close: parseFloat(close),
          volume: parseInt(volume),
          count: parseInt(count),
          wap: parseFloat(wap)
        })
      }

      this.api.on(EventName.historicalData, onBar)

      this.api.reqHistoricalData(
        reqId,
        { symbol, exchange, currency },
        duration,
        barSize,
        whatToShow,
        useRth ? 1 : 0,
        1 // formatDate: 1 = YYYYMMDD  HH:MM:SS
      )
    })
  }

  // Subscribe to real-time bars
  reqRealtimeBars({
    symbol,
    exchange = 'SMART',
    currency = 'USD',
    barSize = 5, // seconds
    whatToShow = 'TRADES',
    useRth = true,
    onBar
  }) {
    const reqId = Math.floor(Math.random() * 100000)

    const handler = (recvReqId, time, open, high, low, close, volume, wap, count) => {
      if (recvReqId !== reqId) return
      onBar({
        date: time,
        open: parseFloat(open),
        high: parseFloat(high),
        low: parseFloat(low),
        close: parseFloat(close),
        volume: parseInt(volume),
        wap: parseFloat(wap),
        count: parseInt(count)
      })
    }

    this.api.on(EventName.realtimeBar, handler)

    this.api.reqRealtimeBars(
      reqId,
      { symbol, exchange, currency },
      barSize,
      whatToShow,
      useRth ? 1 : 0
    )

    return {
      cancel: () => {
        this.api.cancelRealtimeBars(reqId)
        this.api.off(EventName.realtimeBar, handler)
      }
    }
  }
}
