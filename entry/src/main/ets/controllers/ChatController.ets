import { common } from '@kit.AbilityKit'

import { ChatViewModel } from '../viewmodels/ChatViewModel'
import { ChatMessage } from '../models/ChatModel'
import { sendChatMessage, ChatMessageDTO, ChatRequest } from '../api/ChatApi'
import { ChatStorage } from '../utils/ChatStorage'
import { AuthStorage } from '../utils/AuthStorage'
import { globalAuthStore } from '../stores/AuthStore'

type VoidCallback = () => void

export class ChatController {
  private viewModel: ChatViewModel
  private thinkingTimer: number = -1

  private readonly minThinkingDuration: number = 2000
  private readonly thinkingInterval: number = 600
  private readonly thinkingTexts: string[] = [
    'AI 正在思考中...',
    '正在整理上下文...',
    '正在生成回复...',
    '马上就好...'
  ]

  constructor(viewModel: ChatViewModel) {
    this.viewModel = viewModel
  }

  async initAuth(
    context: common.UIAbilityContext,
    onAuthFailed: VoidCallback,
    onScrollToBottom: VoidCallback
  ): Promise<void> {
    const authCache = await AuthStorage.getAuthCache(context)

    if (!authCache) {
      globalAuthStore.clearAuth()
      this.viewModel.clearAuth()
      onAuthFailed()
      return
    }

    globalAuthStore.setAuth(authCache.token, authCache.userInfo)
    this.viewModel.setAuth(authCache.token, authCache.userInfo)

    await this.loadChatCache(context, onScrollToBottom)
  }

  async loadChatCache(
    context: common.UIAbilityContext,
    onScrollToBottom: VoidCallback
  ): Promise<void> {
    const cacheData = await ChatStorage.getChatCache(context)

    this.viewModel.setChatCache(
      cacheData.conversationId,
      cacheData.chatList
    )

    onScrollToBottom()
  }

  async saveChatCache(context: common.UIAbilityContext): Promise<void> {
    await ChatStorage.saveChatCache(
      context,
      this.viewModel.conversationId,
      this.viewModel.chatList
    )
  }

  async clearChatHistory(context: common.UIAbilityContext): Promise<void> {
    this.stopThinkingTimer()
    this.viewModel.clearChat()

    await ChatStorage.clearChatCache(context)
  }

  async logout(
    context: common.UIAbilityContext,
    onLogoutSuccess: VoidCallback
  ): Promise<void> {
    this.stopThinkingTimer()

    await AuthStorage.clearAuthCache(context)

    globalAuthStore.clearAuth()
    this.viewModel.clearAuth()

    onLogoutSuccess()
  }

  wait(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve()
      }, ms)
    })
  }

  startThinkingBubble(onScrollToBottom: VoidCallback): number {
    const thinkingId: number = Date.now() + 1

    this.stopThinkingTimer()

    this.viewModel.startThinking(thinkingId)

    const thinkingMessage: ChatMessage = {
      id: thinkingId,
      role: 'assistant',
      content: this.thinkingTexts[0],
      createTime: thinkingId
    }

    this.viewModel.appendMessage(thinkingMessage)
    onScrollToBottom()

    this.thinkingTimer = setInterval(() => {
      const nextIndex: number = (this.viewModel.thinkingTextIndex + 1) % this.thinkingTexts.length

      this.viewModel.updateThinkingIndex(nextIndex)
      this.updateThinkingBubble(
        thinkingId,
        this.thinkingTexts[nextIndex],
        onScrollToBottom
      )
    }, this.thinkingInterval)

    return thinkingId
  }

  updateThinkingBubble(
    thinkingId: number,
    content: string,
    onScrollToBottom: VoidCallback
  ): void {
    const nextList: ChatMessage[] = this.viewModel.chatList.map((item: ChatMessage): ChatMessage => {
      if (item.id !== thinkingId) {
        return item
      }

      const nextMessage: ChatMessage = {
        id: item.id,
        role: item.role,
        content: content,
        createTime: item.createTime
      }

      return nextMessage
    })

    this.viewModel.replaceChatList(nextList)
    onScrollToBottom()
  }

  stopThinkingTimer(): void {
    if (this.thinkingTimer !== -1) {
      clearInterval(this.thinkingTimer)
      this.thinkingTimer = -1
    }
  }

  replaceThinkingBubble(thinkingId: number, messages: ChatMessage[]): void {
    this.stopThinkingTimer()

    const nextList: ChatMessage[] = this.viewModel.chatList.filter((item: ChatMessage): boolean => {
      return item.id !== thinkingId
    })

    this.viewModel.replaceChatList(nextList.concat(messages))
    this.viewModel.clearThinking()
  }

  getMessageKey(item: ChatMessage): string {
    if (item.id === this.viewModel.thinkingMessageId) {
      return `${item.id}-${item.content}`
    }

    return `${item.id}`
  }

  async sendMessage(
    context: common.UIAbilityContext,
    onScrollToBottom: VoidCallback
  ): Promise<void> {
    const content: string = this.viewModel.inputValue.trim()

    if (!content || this.viewModel.isSending || !this.viewModel.isAuthReady) {
      return
    }

    this.viewModel.setSending(true)
    this.viewModel.setInputValue('')

    const now: number = Date.now()

    const tempUserMessage: ChatMessage = {
      id: now,
      role: 'user',
      content: content,
      createTime: now
    }

    this.viewModel.appendMessage(tempUserMessage)
    await this.saveChatCache(context)
    onScrollToBottom()

    const thinkingId: number = this.startThinkingBubble(onScrollToBottom)
    const thinkingStartTime: number = Date.now()

    try {
      const requestParams: ChatRequest = {
        content: content
      }

      if (this.viewModel.conversationId > 0) {
        requestParams.conversationId = this.viewModel.conversationId
      }

      const res = await sendChatMessage(requestParams)

      const elapsed: number = Date.now() - thinkingStartTime

      if (elapsed < this.minThinkingDuration) {
        await this.wait(this.minThinkingDuration - elapsed)
      }

      if (res.code !== 0) {
        const failNow: number = Date.now()

        const failMessage: ChatMessage = {
          id: failNow,
          role: 'assistant',
          content: res.message || '后端返回异常，请稍后重试。',
          createTime: failNow
        }

        this.replaceThinkingBubble(thinkingId, [failMessage])
        await this.saveChatCache(context)
        onScrollToBottom()
        return
      }

      this.viewModel.setConversationId(res.data.conversationId)

      const assistantMessages: ChatMessage[] = res.data.messages
        .filter((item: ChatMessageDTO) => item.role === 'assistant')
        .map((item: ChatMessageDTO): ChatMessage => {
          const message: ChatMessage = {
            id: item.id,
            role: item.role,
            content: item.content,
            createTime: item.createTime
          }

          return message
        })

      this.replaceThinkingBubble(thinkingId, assistantMessages)
      await this.saveChatCache(context)
      onScrollToBottom()
    } catch (error) {
      console.error(`send message error: ${JSON.stringify(error)}`)

      const elapsed: number = Date.now() - thinkingStartTime

      if (elapsed < this.minThinkingDuration) {
        await this.wait(this.minThinkingDuration - elapsed)
      }

      const errorNow: number = Date.now()

      const errorMessage: ChatMessage = {
        id: errorNow,
        role: 'assistant',
        content: '请求后端失败，请检查 Next.js 服务是否启动，以及接口地址是否正确。',
        createTime: errorNow
      }

      this.replaceThinkingBubble(thinkingId, [errorMessage])
      await this.saveChatCache(context)
      onScrollToBottom()
    } finally {
      this.stopThinkingTimer()
      this.viewModel.setSending(false)
    }
  }

  release(): void {
    this.stopThinkingTimer()
  }
}