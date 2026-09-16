import { http } from '@kit.NetworkKit'
import { LogUtil, SseDoneMeta } from 'common'
import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage, ChatHistoryItem } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { MessageStatus } from '../models/MessageStatus'
import { ChatError } from '../models/ChatError'

const TAG: string = 'ChatStreamStateMachine'

/**
 * 单次聊天流式请求的运行时状态机。
 *
 * 本类独占当前 HTTP 请求、活动消息引用和幂等标记，负责把 SSE 回调转换为
 * 消息状态与 ViewModel loading 状态。它不创建消息，也不决定发送、重发或
 * 重新生成的目标；这些用户操作仍由 ChatController 编排。
 */
export class ChatStreamStateMachine {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  /** 当前唯一的在途请求；请求结束或停止后立即清空。 */
  private currentRequest: http.HttpRequest | null = null
  /** 当前接收流式正文的 AI 消息。 */
  private activeAiMessage: ChatMessage | null = null
  /** 当前轮次的用户消息，用于在首包、失败或停止时推进状态。 */
  private activeUserMessage: ChatMessage | null = null

  /** 每次启动或停止都会推进序号，使旧请求的迟到回调自动失效。 */
  private requestSeq: number = 0
  /** 防止 onDone 与 onError 对同一请求重复收尾。 */
  private finalized: boolean = true
  /** 无部分回复时，是否把用户消息标为可重发失败。 */
  private allowUserResend: boolean = true

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  /**
   * 启动一轮流式请求并接管其全部运行时状态。
   *
   * @param userMsg 本轮用户消息，content 作为请求正文
   * @param aiMsg 接收增量内容和卡片的 AI 消息
   * @param history 不含本轮消息的上下文快照
   * @param allowUserResend 无内容失败时是否保留用户消息供重新发送
   */
  start(
    userMsg: ChatMessage,
    aiMsg: ChatMessage,
    history: ChatHistoryItem[],
    allowUserResend: boolean
  ): void {
    const seq = ++this.requestSeq
    this.finalized = false
    this.allowUserResend = allowUserResend
    this.activeUserMessage = userMsg
    this.activeAiMessage = aiMsg
    this.vm.isLoading = true

    const content = userMsg.content ? userMsg.content : ''
    this.currentRequest = this.biz.sendMessageStream(
      content,
      this.vm.sessionId ? this.vm.sessionId : undefined,
      history,
      {
        onChunk: (chunk: string) => {
          if (this.isStale(seq) || !this.activeAiMessage) {
            return
          }
          if (this.activeUserMessage && this.activeUserMessage.status === MessageStatus.SENDING) {
            this.activeUserMessage.status = MessageStatus.DONE
          }
          if (this.activeAiMessage.status === MessageStatus.THINKING) {
            this.activeAiMessage.status = MessageStatus.STREAMING
          }
          this.activeAiMessage.content += (chunk ? chunk : '')
        },
        onDone: (meta: SseDoneMeta) => {
          if (this.isStale(seq) || this.finalized) {
            return
          }
          if (meta.error) {
            this.finalizeFailure(ChatError.server(meta.error))
            return
          }
          if (meta.sessionId) {
            this.vm.sessionId = meta.sessionId
            if (this.activeAiMessage) {
              this.activeAiMessage.sessionId = meta.sessionId
            }
          }
          if (meta.messageId && this.activeAiMessage) {
            this.activeAiMessage.id = meta.messageId
          }
          if (meta.card && this.activeAiMessage) {
            this.activeAiMessage.card = meta.card
          }
          const hasContent = this.activeAiMessage !== null && this.activeAiMessage.content.length > 0
          const hasCard = this.activeAiMessage !== null && this.activeAiMessage.card !== null
          if (!hasContent && !hasCard) {
            this.finalizeFailure(ChatError.empty())
            return
          }
          this.finalizeSuccess()
        },
        onError: (errMsg: string) => {
          if (this.isStale(seq) || this.finalized) {
            return
          }
          LogUtil.e(TAG, 'stream error: ' + errMsg)
          this.finalizeFailure(ChatError.network(errMsg))
        }
      }
    )
  }

  /**
   * 停止当前请求。停止会先推进请求序号，再销毁连接，确保迟到回调不能修改消息。
   * 无在途请求时直接忽略。
   */
  stop(): void {
    if (!this.vm.isLoading) {
      return
    }
    LogUtil.i(TAG, 'stop generation')
    this.requestSeq++

    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (error) {
        LogUtil.e(TAG, 'destroy request failed: ' + JSON.stringify(error))
      }
      this.currentRequest = null
    }

    if (this.activeAiMessage) {
      this.activeAiMessage.status = MessageStatus.STOPPED
      this.activeAiMessage.errorHint = ''
    }
    if (this.activeUserMessage) {
      this.activeUserMessage.status = MessageStatus.DONE
    }
    this.finishRequest()
  }

  /** 正常完成时，用户消息和 AI 消息统一进入 DONE。 */
  private finalizeSuccess(): void {
    if (this.activeUserMessage) {
      this.activeUserMessage.status = MessageStatus.DONE
    }
    if (this.activeAiMessage) {
      this.activeAiMessage.status = MessageStatus.DONE
      this.activeAiMessage.errorHint = ''
    }
    this.finishRequest()
  }

  /**
   * 失败收尾保留原有三种语义：部分回复标 AI 失败；首次发送无内容时保留用户
   * 重发入口并移除空 AI 占位；重新生成无内容时则保留失败的 AI 气泡。
   */
  private finalizeFailure(error: ChatError): void {
    LogUtil.e(TAG, `finalize failure: ${error.type} ${error.message}`)
    const ai = this.activeAiMessage
    const hasPartial = ai !== null && (ai.content.length > 0 || ai.card !== null)

    if (hasPartial && ai !== null) {
      if (this.activeUserMessage) {
        this.activeUserMessage.status = MessageStatus.DONE
      }
      ai.status = MessageStatus.FAILED
      ai.errorHint = error.toUserHint()
    } else if (this.allowUserResend) {
      if (this.activeUserMessage) {
        this.activeUserMessage.status = MessageStatus.FAILED
        this.activeUserMessage.errorHint = error.toUserHint()
      }
      if (ai !== null) {
        this.removeMessage(ai)
      }
    } else if (ai !== null) {
      ai.status = MessageStatus.FAILED
      ai.errorHint = error.toUserHint()
    }
    this.finishRequest()
  }

  /** 统一释放请求级引用；只有本类可以结束 loading 生命周期。 */
  private finishRequest(): void {
    this.finalized = true
    this.vm.isLoading = false
    this.activeAiMessage = null
    this.activeUserMessage = null
    this.currentRequest = null
  }

  private isStale(seq: number): boolean {
    return seq !== this.requestSeq
  }

  private removeMessage(target: ChatMessage): void {
    const idx = this.vm.historyMessage.indexOf(target)
    if (idx >= 0) {
      this.vm.historyMessage.splice(idx, 1)
    }
  }
}
