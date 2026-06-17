import { NextResponse } from 'next/server'
import { removeTodo } from '@/lib/todoStore'

// DELETE /api/todos/:id —— 删除待办（对应 demo HttpUtil.del）
// 注意：Next.js 16 起，动态路由的 params 是 Promise，必须 await。
export async function DELETE(
  _req: Request,
  ctx: { params: Promise<{ id: string }> },
) {
  const { id } = await ctx.params
  const removed = removeTodo(id)

  if (!removed) {
    return NextResponse.json(
      { code: 404, message: '待办不存在', data: null },
      { status: 404 },
    )
  }

  return NextResponse.json({
    code: 200,
    message: 'success',
    data: removed,
  })
}
