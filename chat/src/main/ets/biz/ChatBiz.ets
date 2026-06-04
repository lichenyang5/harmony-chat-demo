import { http } from '@kit.NetworkKit'
import { SseCallbacks } from 'common'
import { ChatImp } from '../imp/ChatImp'
import { ChatHistoryItem } from '../models/chatModel'

export class ChatBiz {
  private imp: ChatImp = new ChatImp()

  /**
   * 流式发送
   * @param history 已有对话历史（含 user / assistant 多轮）
   */
  sendMessageStream(
    content: string,
    sessionId: string | undefined,
    history: ChatHistoryItem[],
    callbacks: SseCallbacks
  ): http.HttpRequest {
    return this.imp.sendMessageStream(content, sessionId, history, callbacks)
  }
}
