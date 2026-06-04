import { http } from '@kit.NetworkKit'
import { SseDoneMeta } from 'common'
import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage, ChatHistoryItem } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'

/**
 * ChatController
 *
 * 流式设计（参考主流 AI 助手）：
 * 1. 发送时往 historyMessage push 两条：用户消息 + 空的 AI 占位消息
 * 2. 保留对 AI 占位消息的引用 activeAiMessage
 * 3. 每收到一个 chunk，直接 activeAiMessage.content += chunk
 *    @Trace content 自动触发对应 MessageBubble 重渲染
 * 4. 流结束时清理引用，loading 退出
 *
 * 为什么不要前端打字机：
 * - 后端已经按 50ms/字 流式推送，是真打字速度
 * - 前端再加打字机会变成"网络已结束但 UI 还在打"的脱节状态
 * - 中断时也会有"缓冲区还有字没出来"的尴尬
 */
export class ChatController {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  // 当前流式请求引用，用于阶段 3 中断
  private currentRequest: http.HttpRequest | null = null

  // 当前正在累积内容的 AI 消息引用
  private activeAiMessage: ChatMessage | null = null

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  sendMessage(): void {
    const content = this.vm.inputContent.trim()
    if (!content || this.vm.isLoading) {
      return
    }

    // 1. 用户消息
    const userMessage = new ChatMessage()
    userMessage.id = `${Date.now()}_user`
    userMessage.role = 'user'
    userMessage.content = content
    userMessage.createTime = Date.now()
    userMessage.sessionId = this.vm.sessionId

    // 2. AI 占位消息（内容空，等流式追加）
    const aiMessage = new ChatMessage()
    aiMessage.id = `${Date.now()}_ai`
    aiMessage.role = 'assistant'
    aiMessage.content = ''
    aiMessage.createTime = Date.now()
    aiMessage.sessionId = this.vm.sessionId

    // 3. 先构造历史快照（必须在 push 当前对话之前，否则后端会把本次 user 也算进历史）
    const historySnapshot: ChatHistoryItem[] = this.vm.historyMessage
      .filter(m => m.content.length > 0)
      .map(m => {
        const item = new ChatHistoryItem()
        item.role = m.role
        item.content = m.content
        return item
      })

    // 4. push 两条到历史；持有 AI 消息引用便于追加
    this.vm.historyMessage.push(userMessage)
    this.vm.historyMessage.push(aiMessage)
    this.activeAiMessage = aiMessage

    // 5. 清输入框 + 进入 loading
    this.vm.inputContent = ''
    this.vm.isLoading = true

    // 6. 发起 SSE 流式请求
    this.currentRequest = this.biz.sendMessageStream(
      content,
      this.vm.sessionId || undefined,
      historySnapshot,
      {
        onChunk: (chunk: string) => {
          if (!this.activeAiMessage) return

          // 关键：直接修改 @Trace content
          // 由 ChatMessage 的 @ObservedV2 触发对应气泡重渲染
          this.activeAiMessage.content += chunk

          // isLoading 现在贯穿整个生成期，
          // 由 onDone / onError / stopGeneration 统一关闭。
          // 这样发送 / 停止按钮的切换能覆盖整个流式过程。
        },

        onDone: (meta: SseDoneMeta) => {
          // 更新会话 ID（首次会话时后端给出）
          if (meta.sessionId) {
            this.vm.sessionId = meta.sessionId
            if (this.activeAiMessage) {
              this.activeAiMessage.sessionId = meta.sessionId
            }
          }
          if (meta.messageId && this.activeAiMessage) {
            this.activeAiMessage.id = meta.messageId
          }

          this.vm.isLoading = false
          this.activeAiMessage = null
          this.currentRequest = null
        },

        onError: (errMsg: string) => {
          console.error('[ChatController] stream error', errMsg)

          if (this.activeAiMessage) {
            this.activeAiMessage.content = '生成失败，请稍后重试'
          }
          this.vm.isLoading = false
          this.activeAiMessage = null
          this.currentRequest = null
        }
      }
    )
  }

  /**
   * 中断生成（阶段 3 接入按钮调用）
   */
  stopGeneration(): void {
    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (_) {}
      this.currentRequest = null
    }

    if (this.activeAiMessage) {
      this.activeAiMessage.content += '\n\n[已停止]'
      this.activeAiMessage = null
    }

    this.vm.isLoading = false
  }
}
