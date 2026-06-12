import { http } from '@kit.NetworkKit'
import { LogUtil, SseDoneMeta } from 'common'
import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage, ChatHistoryItem } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { MessageStatus } from '../models/MessageStatus'
import { ChatError } from '../models/ChatError'
import { ChatRole } from '../constants/ChatConstants'

const TAG: string = 'ChatController'

/**
 * ChatController —— 消息收发编排
 *
 * 一条「轮次」的生命周期：
 * 1. 创建 user 消息（SENDING）+ AI 占位（THINKING），push 进 chatHistory。
 * 2. runStream 发起 SSE，回调里推进状态：
 *    首个 chunk → user 转 DONE、AI 转 STREAMING；
 *    done      → 成功 DONE / 服务端错误 / 空回复；
 *    error     → 传输失败。
 * 3. 终态落库由 ChatTabComp 监听 isLoading=false 触发。
 *
 * 三类入口共用私有核心 runStream：
 * - sendMessage   首次发送
 * - resendMessage  失败用户消息「重新发送」（复用同一 user 对象）
 * - regenerate     助理消息「重新生成」（复用同一 AI 气泡）
 *
 * 防止同一请求重复写入（幂等）：
 * - requestSeq：每次发起自增，回调捕获自己的 seq；stop / 新一轮会让旧 seq 失效，
 *   旧请求的残留回调命中 isStale 直接 return，不再改 chatHistory。
 * - finalized：每个请求只允许 finalize 一次，onDone / onError 互斥，杜绝双写。
 * - 复用既有消息对象（不重复 push），从源头避免重复气泡。
 */
export class ChatController {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  /** 当前流式请求引用，用于中断 */
  private currentRequest: http.HttpRequest | null = null
  /** 当前正在累积内容的 AI 消息引用 */
  private activeAiMessage: ChatMessage | null = null
  /** 当前轮次的用户消息引用（首 chunk 时转 DONE，失败时可能转 FAILED） */
  private activeUserMessage: ChatMessage | null = null

  /** 单调递增的请求序号，用于让过期请求的回调失效 */
  private requestSeq: number = 0
  /** 当前请求是否已 finalize（初始 true：没有在途请求） */
  private finalized: boolean = true
  /** 本轮失败且 AI 无内容时，是否允许把用户消息标失败可重发（send/resend=true，regenerate=false） */
  private allowUserResend: boolean = true
  /** 消息 id 去重种子，保证同毫秒创建的气泡 id 唯一（ForEach key 用） */
  private idSeed: number = 0

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  // ─── 对外入口 ───────────────────────────────────────────────────────────────

  /** 首次发送输入框内容 */
  sendMessage(): void {
    const content = this.vm.inputContent.trim()
    if (!content || this.vm.isLoading) {
      return
    }
    LogUtil.iPrivate(TAG, '用户发送: %{private}s', content)

    if (!this.vm.sessionId) {
      this.vm.sessionId = Date.now().toString()
    }

    const userMessage = this.createMessage(ChatRole.USER, content, MessageStatus.SENDING)
    const aiMessage = this.createMessage(ChatRole.ASSISTANT, '', MessageStatus.THINKING)

    // 历史快照必须在 push 新消息「之前」取，避免把本轮空 AI 占位也带进上下文
    const history = this.buildHistorySnapshot(this.vm.historyMessage.length)

    this.vm.historyMessage.push(userMessage)
    this.vm.historyMessage.push(aiMessage)
    this.vm.inputContent = ''

    this.runStream(userMessage, aiMessage, history, true)
  }

  /**
   * 重新发送一条失败的用户消息。
   * 复用同一条 user 对象（不再 push 新的）—— 防止重复写入。
   */
  resendMessage(target: ChatMessage): void {
    if (this.vm.isLoading || !target || target.role !== ChatRole.USER) {
      return
    }
    const idx = this.vm.historyMessage.indexOf(target)
    const content = target.content ? target.content : ''
    if (idx < 0 || content.length === 0) {
      return
    }

    // 上下文 = 这条用户消息之前的内容（不含它本身）
    const history = this.buildHistorySnapshot(idx)

    // 复用 user 对象，重置为 SENDING
    target.status = MessageStatus.SENDING
    target.errorHint = ''

    // 追加新的 AI 占位（上次失败时空占位已被移除），插在该用户消息之后
    const aiMessage = this.createMessage(ChatRole.ASSISTANT, '', MessageStatus.THINKING)
    this.vm.historyMessage.splice(idx + 1, 0, aiMessage)

    this.runStream(target, aiMessage, history, true)
  }

  /**
   * 重新生成一条助理消息。
   * 复用同一条 AI 气泡（清空内容重来）—— 防止新增重复气泡。
   */
  regenerate(target: ChatMessage): void {
    if (this.vm.isLoading || !target || target.role !== ChatRole.ASSISTANT) {
      return
    }
    const aiIdx = this.vm.historyMessage.indexOf(target)
    if (aiIdx < 0) {
      return
    }

    // 找它前面最近的一条用户消息作为本轮 prompt
    let promptIdx = -1
    for (let i = aiIdx - 1; i >= 0; i--) {
      if (this.vm.historyMessage[i].role === ChatRole.USER) {
        promptIdx = i
        break
      }
    }
    if (promptIdx < 0) {
      return
    }
    const promptMsg = this.vm.historyMessage[promptIdx]
    const content = promptMsg.content ? promptMsg.content : ''
    if (content.length === 0) {
      return
    }

    // 上下文 = prompt 之前（不含 prompt，runStream 会把 prompt.content 当本轮发送内容）
    const history = this.buildHistorySnapshot(promptIdx)

    // 复用同一 AI 气泡，清空重来
    target.content = ''
    target.card = null
    target.status = MessageStatus.THINKING
    target.errorHint = ''
    promptMsg.status = MessageStatus.DONE

    // allowUserResend=false：重新生成失败时保留 AI 气泡为 FAILED，而不是反过来标用户失败
    this.runStream(promptMsg, target, history, false)
  }

  /**
   * 中断生成。
   * 把「已停止」建模成独立状态（STOPPED），UI 渲染成分割线 + 提示，
   * 不再 content += '[已停止]' 污染正文。
   */
  stopGeneration(): void {
    if (!this.vm.isLoading) {
      return
    }
    LogUtil.i(TAG, 'stop generation')

    // 让在途请求的残留回调失效（seq 变化 → isStale 命中）
    this.requestSeq++

    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (_) {
      }
      this.currentRequest = null
    }

    if (this.activeAiMessage) {
      this.activeAiMessage.status = MessageStatus.STOPPED
      this.activeAiMessage.errorHint = ''
    }
    // 用户消息此刻已送达，标 DONE，避免停留在 SENDING 一直转圈
    if (this.activeUserMessage) {
      this.activeUserMessage.status = MessageStatus.DONE
    }

    this.finishRequest()
  }

  // ─── 私有核心 ───────────────────────────────────────────────────────────────

  /**
   * 发起一次流式请求并接管回调推进状态。
   *
   * @param userMsg        本轮用户消息（其 content 即发送内容）
   * @param aiMsg          本轮 AI 气泡（流式内容累积到这里）
   * @param history        上下文快照（不含本轮）
   * @param allowUserResend 失败且 AI 无内容时，是否标用户消息失败可重发
   */
  private runStream(
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
          // 首个 chunk 到达：用户消息算送达、AI 进入流式
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
          // 服务端逻辑错误（done 帧带 error）
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
          // 流结束但既无文本又无卡片 → 视作失败
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

  /** 正常完成：user + ai 同置 DONE */
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
   * 失败收尾，分两种语义：
   * - AI 已有部分内容（流式中途断）→ 用户消息算送达，AI 气泡 FAILED（可重新生成）。
   * - AI 一个字都没来 →
   *     allowUserResend=true（send/resend）：标用户消息 FAILED 可重发，移除空 AI 占位；
   *     allowUserResend=false（regenerate）：保留 AI 气泡为 FAILED。
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

  /** 统一收尾：解锁 + 清引用 + 标记 finalized */
  private finishRequest(): void {
    this.finalized = true
    this.vm.isLoading = false
    this.activeAiMessage = null
    this.activeUserMessage = null
    this.currentRequest = null
  }

  /** 过期请求判定：seq 与当前不一致说明已被 stop / 新一轮取代 */
  private isStale(seq: number): boolean {
    return seq !== this.requestSeq
  }

  /** 从 chatHistory 中按引用移除一条消息 */
  private removeMessage(target: ChatMessage): void {
    const idx = this.vm.historyMessage.indexOf(target)
    if (idx >= 0) {
      this.vm.historyMessage.splice(idx, 1)
    }
  }

  /** 创建一条消息（统一生成唯一 id） */
  private createMessage(role: ChatRole, content: string, status: MessageStatus): ChatMessage {
    const msg = new ChatMessage()
    const now = Date.now()
    this.idSeed++
    msg.id = `${now}_${role}_${this.idSeed}`
    msg.role = role
    msg.content = content
    msg.createTime = now
    msg.sessionId = this.vm.sessionId
    msg.status = status
    return msg
  }

  /**
   * 构造历史上下文快照（取 [0, endExclusive) 区间内有内容的消息）。
   * 空内容做防御，避免历史脏数据导致 content.length 崩溃。
   */
  private buildHistorySnapshot(endExclusive: number): ChatHistoryItem[] {
    const result: ChatHistoryItem[] = []
    const end = Math.min(endExclusive, this.vm.historyMessage.length)
    for (let i = 0; i < end; i++) {
      const m = this.vm.historyMessage[i]
      const safe = m.content ? m.content : ''
      if (safe.length === 0) {
        continue
      }
      const item = new ChatHistoryItem()
      item.role = m.role ? m.role : ChatRole.ASSISTANT
      item.content = safe
      result.push(item)
    }
    return result
  }
}
