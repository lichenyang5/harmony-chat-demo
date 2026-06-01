import { ApiConstants } from '../constants/ApiConstants'
import { ApiResponse, ChatMessage } from '../models/chatModel'
import { HttpUtil } from '../utils/HttpUtil'

export class ChatImp {
  sendMessage(content: string, sessionId?: string): Promise<ApiResponse<ChatMessage>> {
    const body: Record<string, Object> = {
      'inputContent': content,
      'sessionId': sessionId ?? ''
    }
    return HttpUtil.post<ChatMessage>(ApiConstants.CHAT, body)
  }
}
