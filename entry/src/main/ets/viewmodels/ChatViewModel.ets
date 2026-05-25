import { ChatMessage } from '../models/ChatModel'
import { UserInfo } from '../models/AuthModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputValue: string = ''
  @Trace chatList: ChatMessage[] = []
  @Trace isSending: boolean = false
  @Trace conversationId: number = 0
  @Trace isAuthReady: boolean = false

  @Trace token: string = ''
  @Trace userInfo: UserInfo | null = null

  @Trace thinkingMessageId: number = 0
  @Trace thinkingTextIndex: number = 0

  setInputValue(value: string): void {
    this.inputValue = value
  }

  setAuth(token: string, userInfo: UserInfo): void {
    this.token = token
    this.userInfo = userInfo
    this.isAuthReady = true
  }

  clearAuth(): void {
    this.token = ''
    this.userInfo = null
    this.isAuthReady = false
  }

  setChatCache(conversationId: number, chatList: ChatMessage[]): void {
    this.conversationId = conversationId
    this.chatList = chatList
  }

  appendMessage(message: ChatMessage): void {
    this.chatList = this.chatList.concat([message])
  }

  appendMessages(messages: ChatMessage[]): void {
    this.chatList = this.chatList.concat(messages)
  }

  replaceChatList(chatList: ChatMessage[]): void {
    this.chatList = chatList
  }

  clearChat(): void {
    this.chatList = []
    this.conversationId = 0
    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
  }

  setSending(value: boolean): void {
    this.isSending = value
  }

  setConversationId(conversationId: number): void {
    this.conversationId = conversationId
  }

  startThinking(thinkingMessageId: number): void {
    this.thinkingMessageId = thinkingMessageId
    this.thinkingTextIndex = 0
  }

  updateThinkingIndex(index: number): void {
    this.thinkingTextIndex = index
  }

  clearThinking(): void {
    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
  }
}