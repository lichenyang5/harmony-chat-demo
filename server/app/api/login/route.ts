import { NextRequest, NextResponse } from 'next/server'

const MOCK_USER = {
  userName: 'admin',
  password: '123456',
  userId: 'user_001',
  token: 'mock_token_abc123',
  createTime: 1748736000000
}

export async function POST(req: NextRequest) {
  const { userName, password } = await req.json()

  if (userName === MOCK_USER.userName && password === MOCK_USER.password) {
    return NextResponse.json({
      code: 200,
      message: 'success',
      data: {
        userId: MOCK_USER.userId,
        userName: MOCK_USER.userName,
        token: MOCK_USER.token,
        createTime: MOCK_USER.createTime
      }
    })
  }

  return NextResponse.json({
    code: 401,
    message: '用户名或密码错误',
    data: null
  })
}
