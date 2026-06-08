import { NextRequest } from 'next/server'
import { randomUUID } from 'crypto'

const MOCK_REPLIES = [
  '这是一个很有意思的问题。让我来仔细分析一下你的需求，然后给出一个相对完整的回答。首先，我们需要明确一下问题的核心要点。',
  '根据你描述的情况，我推荐你可以从三个方向来考虑：第一，先理清当前的关键约束；第二，列出所有可行的方案；第三，对比每个方案的优劣后再做决定。',
  '好的，我理解你的意思了。简单来说，这件事可以分成两步走。第一步先把基础打好，确保流程跑通；第二步再去做体验优化和细节打磨。',
  '从技术角度看，这个问题其实有几种实现方式。最简单直接的做法是用现有的 API 直接调用；如果对性能有要求，可以考虑做一层缓存；如果还要支持并发，那就得引入队列。',
  '不错的提问。其实这个话题展开讲可以非常深入。我先给你一个简要的答案：核心思想是分而治之，把复杂的问题拆解成若干个小问题，逐个解决，最后再把结果合起来。'
]

// 打车场景：上方引导文案（走 SSE chunk 流式推送）
const TAXI_INTRO =
  '目的地已为你选择香港国际机场，推荐上车点为香港会展中心，该点附近存在多个点位或管控严格，请确认上车点。'

// 打车场景：下方"确认上车点"卡片，结构化字段随 done 帧一次性下发
interface PickupPoint {
  index: number
  name: string
  address: string
  distance: string
  entrance?: string
}

interface PickupCard {
  type: 'pickup_confirm'
  title: string
  question: string
  currentLocation: string
  points: PickupPoint[]
  moreText: string
}

const TAXI_CARD: PickupCard = {
  type: 'pickup_confirm',
  title: '确认上车点',
  question: '您在哪里上车?',
  currentLocation: '香港中国企业协会',
  points: [
    {
      index: 1,
      name: '香港西九龙站',
      address: '香港特别行政区油尖旺区柯士甸道西3号',
      distance: '65.9km',
      entrance: '进站口1'
    },
    {
      index: 2,
      name: '高铁西九龙站(K出口)',
      address: '香港特别行政区油尖旺区柯士甸道西3号',
      distance: '65.9km'
    },
    {
      index: 3,
      name: '高铁西九龙站(K出口)',
      address: '香港特别行政区油尖旺区柯士甸道西3号',
      distance: '65.9km'
    }
  ],
  moreText: '查看更多'
}

interface HistoryItem {
  role: string
  content: string
}

interface SseFrame {
  chunk?: string
  done: boolean
  sessionId?: string
  messageId?: string
  card?: PickupCard
}

function isTaxiIntent(input: string): boolean {
  return input.trim() === '打车' || input.includes('打车')
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

export async function POST(req: NextRequest) {
  const { inputContent, sessionId, history } = await req.json() as {
    inputContent: string
    sessionId?: string
    history?: HistoryItem[]
  }

  if (!inputContent) {
    return new Response(
      `data: ${JSON.stringify({ done: true, error: '消息内容不能为空' })}\n\n`,
      { status: 400, headers: { 'Content-Type': 'text/event-stream' } }
    )
  }

  const taxi = isTaxiIntent(inputContent)

  // 计算当前是第几轮对话
  // history 里只包含已完成的消息（不含本次 inputContent）
  // 每轮 = 1 个 user + 1 个 assistant
  const userCount = (history ?? []).filter(m => m.role === 'user').length
  const currentTurn = userCount + 1   // 当前是第几轮（含本次）

  let replyContent: string
  if (taxi) {
    replyContent = TAXI_INTRO
  } else {
    // 多轮时在回复前加上下文标记，让前端能看到 history 真的传过去了
    const baseReply = MOCK_REPLIES[Math.floor(Math.random() * MOCK_REPLIES.length)]
    replyContent = currentTurn > 1
      ? `（第 ${currentTurn} 轮 · 我记得前面聊过 ${userCount} 个问题）\n\n${baseReply}`
      : baseReply
  }

  const finalSessionId = sessionId || randomUUID()
  const messageId = randomUUID()

  const encoder = new TextEncoder()
  const stream = new ReadableStream({
    async start(controller) {
      try {
        for (const ch of replyContent) {
          const frame: SseFrame = { chunk: ch, done: false }
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(frame)}\n\n`))
          await sleep(50)
        }
        const endFrame: SseFrame = {
          done: true,
          sessionId: finalSessionId,
          messageId
        }
        if (taxi) {
          endFrame.card = TAXI_CARD
        }
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(endFrame)}\n\n`))
      } catch (err) {
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
      'X-Accel-Buffering': 'no'
    }
  })
}
