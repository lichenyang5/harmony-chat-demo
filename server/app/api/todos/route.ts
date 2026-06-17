import { NextRequest, NextResponse } from 'next/server'
import { listTodos, addTodo } from '@/lib/todoStore'

// GET /api/todos —— 待办列表（对应 demo HttpUtil.get）
export async function GET() {
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: listTodos(),
  })
}

// POST /api/todos —— 新增待办（对应 demo HttpUtil.post）
export async function POST(req: NextRequest) {
  const body = (await req.json()) as { title?: string }
  const title = (body.title ?? '').trim()

  if (!title) {
    return NextResponse.json(
      { code: 400, message: '标题不能为空', data: null },
      { status: 400 },
    )
  }

  const todo = addTodo(title)
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: todo,
  })
}
