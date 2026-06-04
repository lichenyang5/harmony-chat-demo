import { ApiConstants } from 'common'
import { ApiResponse } from 'common'
import { ChatMessage } from '../models/chatModel'
import { HttpUtil } from 'common'

export class ChatImp {
  sendMessage(content: string, sessionId?: string): Promise<ApiResponse<ChatMessage>> {
    const body: Record<string, Object> = {
      'inputContent': content,
      'sessionId': sessionId ?? ''
    }
    return HttpUtil.post<ChatMessage>(ApiConstants.CHAT, body)
  }
}
