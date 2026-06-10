import { http } from '@kit.NetworkKit'
import { LogUtil, SseDoneMeta } from 'common'
import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage, ChatHistoryItem } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'

/**
 * ChatController
 *
 * 流式设计：
 * 1. 发送时往 historyMessage push 两条：用户消息 + 空的 AI 占位消息。
 * 2. 保留对 AI 占位消息的引用 activeAiMessage。
 * 3. 每收到一个 chunk，直接 activeAiMessage.content += chunk。
 * 4. ChatMessage.content 是 @Trace，UI 会自动更新对应气泡。
 */
export class ChatController {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  // 当前流式请求引用，用于中断
  private currentRequest: http.HttpRequest | null = null

  // 当前正在累积内容的 AI 消息引用
  private activeAiMessage: ChatMessage | null = null

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  sendMessage(): void {
    const content = this.vm.inputContent.trim()
    LogUtil.iPrivate('ChatController', '用户发送: %{private}s', content)
    if (!content || this.vm.isLoading) {
      return
    }

    // 如果当前会话 ID 为空，兜底生成一个
    if (!this.vm.sessionId) {
      this.vm.sessionId = Date.now().toString()
    }

    // 1. 用户消息
    const userMessage = new ChatMessage()
    userMessage.id = `${Date.now()}_user`
    userMessage.role = 'user'
    userMessage.content = content
    userMessage.createTime = Date.now()
    userMessage.sessionId = this.vm.sessionId

    // 2. AI 占位消息，内容为空，等流式 chunk 追加
    const aiMessage = new ChatMessage()
    aiMessage.id = `${Date.now()}_ai`
    aiMessage.role = 'assistant'
    aiMessage.content = ''
    aiMessage.createTime = Date.now()
    aiMessage.sessionId = this.vm.sessionId

    // 3. 构造历史快照
    // 注意：这里 content 必须做空值防御，避免历史脏数据导致 m.content.length 崩溃。
    const historySnapshot: ChatHistoryItem[] = this.vm.historyMessage
      .filter((m: ChatMessage) => {
        const safeContent = m.content ? m.content : ''
        return safeContent.length > 0
      })
      .map((m: ChatMessage) => {
        const item = new ChatHistoryItem()
        item.role = m.role ? m.role : 'assistant'
        item.content = m.content ? m.content : ''
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
      this.vm.sessionId ? this.vm.sessionId : undefined,
      historySnapshot,
      {
        onChunk: (chunk: string) => {
          if (!this.activeAiMessage) {
            return
          }

          const safeChunk = chunk ? chunk : ''
          this.activeAiMessage.content += safeChunk
        },

        onDone: (meta: SseDoneMeta) => {
          if (meta.sessionId) {
            this.vm.sessionId = meta.sessionId

            if (this.activeAiMessage) {
              this.activeAiMessage.sessionId = meta.sessionId
            }
          }

          if (meta.messageId && this.activeAiMessage) {
            this.activeAiMessage.id = meta.messageId
          }

          // 后端 done 帧附带 card → UI 切到卡片渲染分支。
          // 这里只透传 raw Object，具体类型由渲染层按 card.type 分发后再 cast。
          if (meta.card && this.activeAiMessage) {
            this.activeAiMessage.card = meta.card
          }

          this.vm.isLoading = false
          this.activeAiMessage = null
          this.currentRequest = null
        },

        onError: (errMsg: string) => {
          LogUtil.e('ChatController', 'stream error: ' + errMsg)

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
   * 中断生成
   */
  stopGeneration(): void {
    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (_) {
      }

      this.currentRequest = null
    }

    if (this.activeAiMessage) {
      const oldContent = this.activeAiMessage.content ? this.activeAiMessage.content : ''

      if (oldContent.length > 0) {
        this.activeAiMessage.content = oldContent + '\n\n[已停止]'
      } else {
        this.activeAiMessage.content = '[已停止]'
      }

      this.activeAiMessage = null
    }

    this.vm.isLoading = false
  }
}