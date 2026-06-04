import { http } from '@kit.NetworkKit'
import { ApiConstants, SseHttpUtil, SseCallbacks } from 'common'
import { ChatHistoryItem } from '../models/chatModel'

export class ChatImp {
  /**
   * 流式发送消息
   * @param history 已有对话历史（多轮上下文）
   */
  sendMessageStream(
    content: string,
    sessionId: string | undefined,
    history: ChatHistoryItem[],
    callbacks: SseCallbacks
  ): http.HttpRequest {
    const body: Record<string, Object> = {
      'inputContent': content,
      'sessionId': sessionId ?? '',
      'history': history
    }
    return SseHttpUtil.postStream(ApiConstants.CHAT, body, callbacks)
  }
}
