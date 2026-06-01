export class ChatMessage {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
}

export class ApiResponse<T> {
  code: number = 0
  message: string = ''
  data: T | null = null
}