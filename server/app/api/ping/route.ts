import { NextResponse } from 'next/server'

export async function GET() {
  return NextResponse.json({
    message: 'pong',
    service: 'harmony-chat-demo-server'
  })
}