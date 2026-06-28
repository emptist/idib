// SSE server: streams chart data + accepts requests via POST /request
// GET  /stream          — SSE stream
// POST /request         — { symbol, intervals: ['1h', '1d'] }
// GET  /chart/:symbol   — current data as JSON

import { createServer } from 'http'

export class SSEServer {
  constructor(port = 3000) {
    this.port = port
    this.server = null
    this.clients = new Set()
    this.latestData = {}
    this.onRequest = null  // callback: async (symbol, intervals) => void
  }

  start() {
    return new Promise((resolve) => {
      this.server = createServer((req, res) => {
        res.setHeader('Access-Control-Allow-Origin', '*')
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

        if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return }

        // SSE stream
        if (req.url === '/stream' && req.method === 'GET') {
          res.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          })
          this.clients.add(res)
          req.on('close', () => this.clients.delete(res))
          if (Object.keys(this.latestData).length > 0) {
            res.write(`data: ${JSON.stringify(this.latestData)}\n\n`)
          }
          return
        }

        // Request data
        if (req.url === '/request' && req.method === 'POST') {
          let body = ''
          req.on('data', c => body += c)
          req.on('end', () => {
            try {
              const { symbol, intervals } = JSON.parse(body)
              if (symbol && intervals?.length && this.onRequest) {
                this.onRequest(symbol, intervals)
                res.writeHead(200, { 'Content-Type': 'application/json' })
                res.end(JSON.stringify({ ok: true }))
              } else {
                res.writeHead(400)
                res.end(JSON.stringify({ error: 'missing symbol or intervals' }))
              }
            } catch (e) {
              res.writeHead(400)
              res.end(JSON.stringify({ error: e.message }))
            }
          })
          return
        }

        // Chart data
        if (req.url?.startsWith('/chart/')) {
          const symbol = req.url.slice(6)
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify(this.latestData[symbol] || null))
          return
        }

        // Dashboard
        if (req.url === '/') {
          const { readFileSync } = await import('fs')
          const { join } = await import('path')
          try {
            const html = readFileSync(join(process.cwd(), 'dashboard.html'), 'utf8')
            res.writeHead(200, { 'Content-Type': 'text/html' })
            res.end(html)
          } catch (_) {
            res.writeHead(200, { 'Content-Type': 'text/html' })
            res.end('<h1>idib</h1>')
          }
          return
        }

        res.writeHead(404); res.end()
      })

      this.server.listen(this.port, () => {
        console.log(`SSE: http://localhost:${this.port}`)
        resolve({ ok: true, port: this.port })
      })
    })
  }

  broadcast(symbol, data) {
    this.latestData[symbol] = data
    const payload = `data: ${JSON.stringify({ symbol, ...data })}\n\n`
    for (const c of this.clients) {
      try { c.write(payload) } catch (_) { this.clients.delete(c) }
    }
  }

  stop() { this.server?.close(); this.clients.clear() }
}
