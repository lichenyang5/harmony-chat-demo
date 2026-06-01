import { NextRequest, NextResponse } from 'next/server'
import { randomUUID } from 'crypto'

const MOCK_REPLIES = [
  '你好！有什么我可以帮助你的吗？',
  '这是一个很好的问题，让我来解释一下。',
  '根据你的描述，我建议你可以这样处理。',
  '明白了，我来帮你分析一下这个情况。',
  '好的，我已经收到你的消息了。'
]

export async function POST(req: NextRequest) {
  const { inputContent, sessionId } = await req.json()

  if (!inputContent) {
    return NextResponse.json({
      code: 400,
      message: '消息内容不能为空',
      data: null
    })
  }

  const replyContent = MOCK_REPLIES[Math.floor(Math.random() * MOCK_REPLIES.length)]

  return NextResponse.json({
    code: 200,
    message: 'success',
    data: {
      id: randomUUID(),
      role: 'assistant',
      content: replyContent,
      createTime: Date.now(),
      sessionId: sessionId || randomUUID()
    }
  })
}
