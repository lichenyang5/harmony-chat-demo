import { NextRequest } from 'next/server'
import { randomUUID } from 'crypto'

/**
 * Mock AI 回复语料库
 * 选成稍长一点的句子，流式输出才有"打字感"
 */
const MOCK_REPLIES = [
  '这是一个很有意思的问题。让我来仔细分析一下你的需求，然后给出一个相对完整的回答。首先，我们需要明确一下问题的核心要点。',
  '根据你描述的情况，我推荐你可以从三个方向来考虑：第一，先理清当前的关键约束；第二，列出所有可行的方案；第三，对比每个方案的优劣后再做决定。',
  '好的，我理解你的意思了。简单来说，这件事可以分成两步走。第一步先把基础打好，确保流程跑通；第二步再去做体验优化和细节打磨。',
  '从技术角度看，这个问题其实有几种实现方式。最简单直接的做法是用现有的 API 直接调用；如果对性能有要求，可以考虑做一层缓存；如果还要支持并发，那就得引入队列。',
  '不错的提问。其实这个话题展开讲可以非常深入。我先给你一个简要的答案：核心思想是分而治之，把复杂的问题拆解成若干个小问题，逐个解决，最后再把结果合起来。'
]

/**
 * SSE chunk 数据帧
 * - 中间帧：{ chunk: '某个字', done: false }
 * - 结束帧：{ done: true, sessionId, messageId }
 */
interface SseFrame {
  chunk?: string
  done: boolean
  sessionId?: string
  messageId?: string
}

/**
 * 按字符延迟工具：模拟 LLM 逐字生成
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

export async function POST(req: NextRequest) {
  const { inputContent, sessionId } = await req.json()

  if (!inputContent) {
    return new Response(
      `data: ${JSON.stringify({ done: true, error: '消息内容不能为空' })}\n\n`,
      { status: 400, headers: { 'Content-Type': 'text/event-stream' } }
    )
  }

  // 选一个 mock 回复
  const replyContent = MOCK_REPLIES[Math.floor(Math.random() * MOCK_REPLIES.length)]
  const finalSessionId = sessionId || randomUUID()
  const messageId = randomUUID()

  const encoder = new TextEncoder()

  // 构造可读流：按字推送
  const stream = new ReadableStream({
    async start(controller) {
      try {
        // 1. 按字符 enqueue
        for (const ch of replyContent) {
          const frame: SseFrame = { chunk: ch, done: false }
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(frame)}\n\n`))
          await sleep(50)   // 50ms / 字，体感接近真实 LLM
        }

        // 2. 结束帧：告诉前端"流结束了"，附带本次会话/消息 ID
        const endFrame: SseFrame = {
          done: true,
          sessionId: finalSessionId,
          messageId
        }
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(endFrame)}\n\n`))
      } catch (err) {
        // 客户端断开连接时 enqueue 会抛错，捕获后就结束
        console.error('[SSE] stream error', err)
      } finally {
        controller.close()
      }
    }
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      // 关闭 Nginx / 边缘服务器的响应缓冲，否则 chunk 不会立即下发
      'X-Accel-Buffering': 'no'
    }
  })
}
