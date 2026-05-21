import { NextResponse } from 'next/server'

type ChatRequestBody = {
  conversationId?: number
  content?: string
}

export async function POST(request: Request) {
  try {
    const body = await request.json() as ChatRequestBody

    const content = String(body.content || '').trim()
    const conversationId = body.conversationId || Date.now()

    if (!content) {
      return NextResponse.json(
        {
          code: 400,
          message: '消息内容不能为空'
        },
        {
          status: 400
        }
      )
    }

    const now = Date.now()

    return NextResponse.json({
      code: 0,
      message: 'success',
      data: {
        conversationId,
        messages: [
          {
            id: now,
            role: 'user',
            content,
            createTime: now
          },
          {
            id: now + 1,
            role: 'assistant',
            content: `这是 Next.js 后端返回的模拟回复：${content}`,
            createTime: now + 1
          }
        ]
      }
    })
  } catch {
    return NextResponse.json(
      {
        code: 500,
        message: '服务端解析请求失败'
      },
      {
        status: 500
      }
    )
  }
}