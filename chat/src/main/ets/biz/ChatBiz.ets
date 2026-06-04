import { http } from '@kit.NetworkKit'
import { SseCallbacks } from 'common'
import { ChatImp } from '../imp/ChatImp'

export class ChatBiz {
  private imp: ChatImp = new ChatImp()

  /**
   * 流式发送：Biz 层目前是透传，未来可以在这里做：
   * - 业务校验（敏感词、长度限制）
   * - chunk 累积、过滤、转换
   * - 失败重试
   */
  sendMessageStream(
    content: string,
    sessionId: string | undefined,
    callbacks: SseCallbacks
  ): http.HttpRequest {
    return this.imp.sendMessageStream(content, sessionId, callbacks)
  }
}
