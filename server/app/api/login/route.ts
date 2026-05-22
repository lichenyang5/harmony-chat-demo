import { NextResponse } from 'next/server'

type LoginRequestBody = {
  username?: string
  password?: string
}

export async function POST(request: Request) {
  try {
    const body = await request.json() as LoginRequestBody

    const username = String(body.username || '').trim()
    const password = String(body.password || '').trim()

    if (!username || !password) {
      return NextResponse.json(
        {
          code: 400,
          message: '账号和密码不能为空'
        },
        {
          status: 400
        }
      )
    }

    if (username !== 'admin' || password !== '123456') {
      return NextResponse.json(
        {
          code: 401,
          message: '账号或密码错误'
        },
        {
          status: 401
        }
      )
    }

    return NextResponse.json({
      code: 0,
      message: 'success',
      data: {
        token: `mock-token-${Date.now()}`,
        userInfo: {
          id: 1,
          username: 'admin',
          nickname: '鸿蒙练习用户',
          avatar: ''
        }
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