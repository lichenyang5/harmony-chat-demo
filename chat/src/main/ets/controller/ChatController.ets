import { http } from '@kit.NetworkKit'
import { SseDoneMeta } from 'common'
import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'

/**
 * ChatController
 *
 * 重点：
 * 1. 网络层负责接收 SSE chunk
 * 2. Controller 不再把 chunk 直接一次性塞给 UI
 * 3. Controller 内部维护 typingBuffer
 * 4. UI 每隔 typingDelay 只追加一个字符，形成真正的打字机效果
 */
export class ChatController {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  // 当前流式请求引用，用于中断
  private currentRequest: http.HttpRequest | null = null

  // 等待被“打字机”消费的文本缓冲区
  private typingBuffer: string = ''

  // 网络是否已经结束
  private networkDone: boolean = false

  // 网络结束时返回的 meta，等打字机打完后再真正入历史消息
  private pendingDoneMeta: SseDoneMeta = {}

  // 是否正在执行打字机
  private typingRunning: boolean = false

  // 定时器 ID
  private typingTimer: number = -1

  // 打字速度：越小越快
  private readonly typingDelay: number = 45

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  sendMessage(): void {
    const content = this.vm.inputContent.trim()

    if (!content || this.vm.isLoading) {
      return
    }

    // 1. 用户消息推入历史
    const userMessage = new ChatMessage()
    userMessage.id = Date.now().toString()
    userMessage.role = 'user'
    userMessage.content = content
    userMessage.createTime = Date.now()

    this.vm.historyMessage.push(userMessage)

    // 2. 清空输入框
    this.vm.inputContent = ''

    // 3. 初始化本次 AI 回复状态
    this.resetTypingState()
    this.vm.isLoading = true
    this.vm.streamingContent = ''

    // 4. 发起流式请求
    this.currentRequest = this.biz.sendMessageStream(
      content,
      this.vm.sessionId || undefined,
      {
        onChunk: (chunk: string) => {
          // 注意：
          // 这里不要直接 this.vm.streamingContent += chunk
          // 否则多个 chunk 在一次 dataReceive 里同步追加，UI 会表现成“一下子全出来”
          this.enqueueTypingText(chunk)
        },

        onDone: (meta: SseDoneMeta) => {
          // 网络结束不代表 UI 打字结束
          // 这里只记录结束状态，等 typingBuffer 全部打完再入历史消息
          this.networkDone = true
          this.pendingDoneMeta = meta

          if (!this.typingRunning && this.typingBuffer.length === 0) {
            this.finishAiMessage()
          }
        },

        onError: (errMsg: string) => {
          console.error('[ChatController] stream error', errMsg)

          this.clearTypingTimer()
          this.resetTypingState()

          this.vm.streamingContent = ''
          this.vm.isLoading = false
          this.currentRequest = null
        }
      }
    )
  }

  /**
   * 把网络 chunk 放进打字机缓冲区
   */
  private enqueueTypingText(chunk: string): void {
    if (!chunk) {
      return
    }

    this.typingBuffer += chunk
    this.startTyping()
  }

  /**
   * 启动打字机
   */
  private startTyping(): void {
    if (this.typingRunning) {
      return
    }

    this.typingRunning = true
    this.typeNext()
  }

  /**
   * 每次只从 typingBuffer 取一个字符追加到 streamingContent
   */
  private typeNext(): void {
    if (this.typingBuffer.length > 0) {
      const nextChar = this.typingBuffer.substring(0, 1)
      this.typingBuffer = this.typingBuffer.substring(1)

      this.vm.streamingContent += nextChar

      this.typingTimer = setTimeout(() => {
        this.typingTimer = -1
        this.typeNext()
      }, this.typingDelay)

      return
    }

    this.typingRunning = false

    // 网络已经结束，并且打字机也打完了，这时才真正把 AI 消息入历史
    if (this.networkDone) {
      this.finishAiMessage()
    }
  }

  /**
   * AI 回复完成：把 streamingContent 转成一条正式历史消息
   */
  private finishAiMessage(): void {
    const meta = this.pendingDoneMeta

    if (this.vm.streamingContent.length > 0) {
      const aiMessage = new ChatMessage()
      aiMessage.id = meta.messageId ?? Date.now().toString()
      aiMessage.role = 'assistant'
      aiMessage.content = this.vm.streamingContent
      aiMessage.createTime = Date.now()
      aiMessage.sessionId = meta.sessionId ?? this.vm.sessionId

      this.vm.historyMessage.push(aiMessage)
    }

    if (meta.sessionId) {
      this.vm.sessionId = meta.sessionId
    }

    this.vm.streamingContent = ''
    this.vm.isLoading = false
    this.currentRequest = null

    this.resetTypingState()
  }

  /**
   * 阶段 3：中断当前生成
   */
  stopGeneration(): void {
    if (!this.currentRequest) {
      return
    }

    try {
      this.currentRequest.destroy()
    } catch (_) {}

    this.currentRequest = null
    this.clearTypingTimer()

    const partialContent = this.vm.streamingContent + this.typingBuffer

    if (partialContent.length > 0) {
      const partial = new ChatMessage()
      partial.id = Date.now().toString()
      partial.role = 'assistant'
      partial.content = partialContent + '\n\n[已停止]'
      partial.createTime = Date.now()
      partial.sessionId = this.vm.sessionId

      this.vm.historyMessage.push(partial)
    }

    this.vm.streamingContent = ''
    this.vm.isLoading = false

    this.resetTypingState()
  }

  private clearTypingTimer(): void {
    if (this.typingTimer !== -1) {
      try {
        clearTimeout(this.typingTimer)
      } catch (_) {}

      this.typingTimer = -1
    }
  }

  private resetTypingState(): void {
    this.clearTypingTimer()

    this.typingBuffer = ''
    this.networkDone = false
    this.pendingDoneMeta = {}
    this.typingRunning = false
  }
}