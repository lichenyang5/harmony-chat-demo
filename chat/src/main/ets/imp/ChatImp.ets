import { http } from '@kit.NetworkKit'
import { ApiConstants, SseHttpUtil, SseCallbacks } from 'common'

export class ChatImp {
  /**
   * 流式发送消息
   * @returns HttpRequest 实例，调用方可以保存它，用于中断（destroy）
   */
  sendMessageStream(
    content: string,
    sessionId: string | undefined,
    callbacks: SseCallbacks
  ): http.HttpRequest {
    const body: Record<string, Object> = {
      'inputContent': content,
      'sessionId': sessionId ?? ''
    }
    return SseHttpUtil.postStream(ApiConstants.CHAT, body, callbacks)
  }
}
