// entry/src/main/ets/models/ChatModel.ets

export interface ChatMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}