import { http } from '@kit.NetworkKit'
import { SseDoneMeta } from 'common'
import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'

export class ChatController {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  // 保留当前流式请求引用，阶段 3 中断时用
  private currentRequest: http.HttpRequest | null = null

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

    // 3. 进入 loading + 清空上一次的流式内容
    this.vm.isLoading = true
    this.vm.streamingContent = ''

    // 4. 发起流式请求
    this.currentRequest = this.biz.sendMessageStream(
      content,
      this.vm.sessionId || undefined,
      {
        onChunk: (chunk: string) => {
          // 每收到一个字，追加到 streamingContent
          // @Trace 会驱动 UI 立即重渲染
          this.vm.streamingContent += chunk
        },

        onDone: (meta: SseDoneMeta) => {
          // 流结束：把累积的 streamingContent 转成完整 AI 消息
          if (this.vm.streamingContent.length > 0) {
            const aiMessage = new ChatMessage()
            aiMessage.id = meta.messageId ?? Date.now().toString()
            aiMessage.role = 'assistant'
            aiMessage.content = this.vm.streamingContent
            aiMessage.createTime = Date.now()
            aiMessage.sessionId = meta.sessionId ?? this.vm.sessionId
            this.vm.historyMessage.push(aiMessage)
          }

          // 更新会话 ID（首次会话时后端给出 sessionId）
          if (meta.sessionId) {
            this.vm.sessionId = meta.sessionId
          }

          // 清空流式缓冲 + 退出 loading
          this.vm.streamingContent = ''
          this.vm.isLoading = false
          this.currentRequest = null
        },

        onError: (errMsg: string) => {
          console.error('[ChatController] stream error', errMsg)
          this.vm.streamingContent = ''
          this.vm.isLoading = false
          this.currentRequest = null
        }
      }
    )
  }

  /**
   * 阶段 3 会用到：中断当前生成
   */
  stopGeneration(): void {
    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (_) {}
      this.currentRequest = null

      // 把已经收到的部分作为半完整消息保留
      if (this.vm.streamingContent.length > 0) {
        const partial = new ChatMessage()
        partial.id = Date.now().toString()
        partial.role = 'assistant'
        partial.content = this.vm.streamingContent + '\n\n[已停止]'
        partial.createTime = Date.now()
        partial.sessionId = this.vm.sessionId
        this.vm.historyMessage.push(partial)
      }

      this.vm.streamingContent = ''
      this.vm.isLoading = false
    }
  }
}
