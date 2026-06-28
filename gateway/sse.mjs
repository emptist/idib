// SSE server: streams chart data, indicators, signals, and positions
// Endpoints:
//   GET /               — dashboard HTML
//   GET /stream         — SSE stream of chart updates
//   GET /chart/:symbol  — current chart data as JSON

import { createServer } from 'http'
import { readFileSync } from 'fs'
import { join } from 'path'

export class SSEServer {
  constructor(port = 3000) {
    this.port = port
    this.server = null
    this.clients = new Set()
    this.latestData = {}
  }

  start() {
    return new Promise((resolve) => {
      this.server = createServer((req, res) => {
        // CORS
        res.setHeader('Access-Control-Allow-Origin', '*')
        res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS')
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

        if (req.method === 'OPTIONS') {
          res.writeHead(200)
          res.end()
          return
        }

        if (req.url === '/stream') {
          // SSE endpoint
          res.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive'
          })

          this.clients.add(res)
          console.log(`SSE: client connected (${this.clients.size} total)`)

          req.on('close', () => {
            this.clients.delete(res)
            console.log(`SSE: client disconnected (${this.clients.size} total)`)
          })

          // Send current state immediately
          if (Object.keys(this.latestData).length > 0) {
            res.write(`data: ${JSON.stringify(this.latestData)}\n\n`)
          }
          return
        }

        if (req.url?.startsWith('/chart/')) {
          const symbol = req.url.slice(6)
          const data = this.latestData[symbol] || null
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify(data))
          return
        }

        // Dashboard
        if (req.url === '/') {
          try {
            const html = readFileSync(join(process.cwd(), 'dashboard.html'), 'utf8')
            res.writeHead(200, { 'Content-Type': 'text/html' })
            res.end(html)
          } catch (_) {
            res.writeHead(200, { 'Content-Type': 'text/html' })
            res.end('<h1>idib</h1><p>Connect via SSE at <a href="/stream">/stream</a></p>')
          }
          return
        }

        res.writeHead(404)
        res.end('Not found')
      })

      this.server.listen(this.port, () => {
        console.log(`SSE: listening on http://localhost:${this.port}`)
        resolve({ ok: true, port: this.port })
      })
    })
  }

  stop() {
    this.server?.close()
    this.clients.clear()
  }

  // Broadcast data to all connected SSE clients
  broadcast(symbol, data) {
    this.latestData[symbol] = data
    const payload = `data: ${JSON.stringify({ symbol, ...data })}\n\n`
    for (const client of this.clients) {
      try {
        client.write(payload)
      } catch (_) {
        this.clients.delete(client)
      }
    }
  }
}
