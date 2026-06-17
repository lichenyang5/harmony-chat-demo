/**
 * 自定义 Node 服务器：在 Next.js 之上挂一个 WebSocket 通道。
 *
 * 为什么需要它：Next.js 的 Route Handlers（app/api/.../route.ts）基于
 * Web Request/Response，拿不到底层 socket，无法做 WebSocket 升级握手。
 * WebSocket 必须在自定义服务器里用 `ws` 处理 upgrade 事件。
 *
 * HTTP（get/post/delete 路由）仍然完全走 Next；
 * 只有 path = /api/ws 的 upgrade 请求被我们接管，其余（Next dev 的 HMR）
 * 交回 Next 自己懒注册的 upgrade 监听器。
 *
 * 启动：npm run dev  ->  node server.js
 * 同源地址：http://192.168.20.8:3000   ws://192.168.20.8:3000/api/ws
 */
const { createServer } = require('http')
const next = require('next')
const { WebSocketServer } = require('ws')

const port = parseInt(process.env.PORT || '3000', 10)
const dev = process.env.NODE_ENV !== 'production'

const app = next({ dev })
const handle = app.getRequestHandler()

app.prepare().then(() => {
  const server = createServer((req, res) => {
    handle(req, res)
  })

  // noServer：自己控制握手时机，只接管 /api/ws
  const wss = new WebSocketServer({ noServer: true })

  server.on('upgrade', (req, socket, head) => {
    let pathname = '/'
    try {
      pathname = new URL(req.url || '/', 'http://localhost').pathname
    } catch {
      pathname = '/'
    }

    if (pathname === '/api/ws') {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req)
      })
    }
    // 其余 upgrade（如 Next dev 的 HMR）不在这里处理，
    // 由 Next 在首个请求后懒注册的 upgrade 监听器接手。
  })

  wss.on('connection', (ws) => {
    let seq = 0
    let online = 8

    safeSend(ws, { type: 'welcome', message: '已连接到 /api/ws 实时通道', serverTime: Date.now() })

    // 每 2s 推一帧，模拟「实时心跳 / 在线人数」
    const timer = setInterval(() => {
      seq += 1
      online += Math.floor(Math.random() * 3) - 1 // 在当前值附近 ±1 游走
      if (online < 1) online = 1
      safeSend(ws, { type: 'tick', seq, serverTime: Date.now(), onlineCount: online })
    }, 2000)

    // 客户端发来的内容原样回显，验证双向通信
    ws.on('message', (raw) => {
      safeSend(ws, { type: 'echo', message: raw.toString(), serverTime: Date.now() })
    })

    const stop = () => clearInterval(timer)
    ws.on('close', stop)
    ws.on('error', stop)
  })

  server.listen(port, () => {
    console.log(`> Ready on http://localhost:${port}`)
    console.log(`> WebSocket on ws://localhost:${port}/api/ws`)
  })
})

function safeSend(ws, payload) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(payload))
  }
}
