import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

import { RouteConstants } from '../constants/RouteConstants'
import { globalTabState } from '../stores/TabState'
import { sendChatMessage, ChatMessageDTO, ChatRequest } from '../api/ChatApi'
import { ChatMessage } from '../models/ChatModel'
import { ChatStorage } from '../utils/ChatStorage'
import { AuthStorage } from '../utils/AuthStorage'
import { globalAuthStore } from '../stores/AuthStore'

@HMRouter({ pageUrl: RouteConstants.SETTING })
@ComponentV2
export struct Setting {
  private listScroller: Scroller = new Scroller()

  // AI 思考气泡相关
  private thinkingTimer: number = -1
  private readonly minThinkingDuration: number = 2000
  private readonly thinkingInterval: number = 600
  private readonly thinkingTexts: string[] = [
    'AI 正在思考中...',
    '正在整理上下文...',
    '正在生成回复...',
    '马上就好...'
  ]

  @Local thinkingMessageId: number = 0
  @Local thinkingTextIndex: number = 0

  @Local inputValue: string = ''
  @Local chatList: ChatMessage[] = []
  @Local isSending: boolean = false
  @Local conversationId: number = 0
  @Local isAuthReady: boolean = false

  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.SETTING)

    // 键盘弹起时，页面整体 resize，避免输入框被遮挡
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)

    // 进入页面时先初始化登录态
    this.initAuth()
  }

  aboutToDisappear(): void {
    this.stopThinkingTimer()
  }

  /**
   * 初始化登录态
   */
  async initAuth(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const authCache = await AuthStorage.getAuthCache(context)

    if (!authCache) {
      globalAuthStore.clearAuth()

      HMRouterMgr.replace({
        pageUrl: RouteConstants.LOGIN
      })

      return
    }

    globalAuthStore.setAuth(authCache.token, authCache.userInfo)
    this.isAuthReady = true

    await this.loadChatCache()
  }

  /**
   * 页面进入时读取本地聊天缓存
   */
  async loadChatCache(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const cacheData = await ChatStorage.getChatCache(context)

    this.conversationId = cacheData.conversationId
    this.chatList = cacheData.chatList

    this.scrollToBottom()
  }

  /**
   * 保存当前聊天缓存
   */
  async saveChatCache(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    await ChatStorage.saveChatCache(context, this.conversationId, this.chatList)
  }

  /**
   * 清空聊天历史
   */
  async clearChatHistory(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext

    this.stopThinkingTimer()
    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
    this.chatList = []
    this.conversationId = 0

    await ChatStorage.clearChatCache(context)
  }

  /**
   * 退出登录
   */
  async logout(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext

    this.stopThinkingTimer()

    await AuthStorage.clearAuthCache(context)
    globalAuthStore.clearAuth()

    HMRouterMgr.replace({
      pageUrl: RouteConstants.LOGIN
    })
  }

  /**
   * 滚动到底部
   */
  scrollToBottom(): void {
    setTimeout(() => {
      this.listScroller.scrollToIndex(this.chatList.length)
    }, 50)
  }

  /**
   * 等待指定时间
   */
  wait(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve()
      }, ms)
    })
  }

  /**
   * 开始展示 AI 思考气泡
   */
  startThinkingBubble(): number {
    const thinkingId: number = Date.now() + 1

    this.stopThinkingTimer()

    this.thinkingMessageId = thinkingId
    this.thinkingTextIndex = 0

    const thinkingMessage: ChatMessage = {
      id: thinkingId,
      role: 'assistant',
      content: this.thinkingTexts[0],
      createTime: thinkingId
    }

    this.chatList = this.chatList.concat([thinkingMessage])
    this.scrollToBottom()

    this.thinkingTimer = setInterval(() => {
      this.thinkingTextIndex = (this.thinkingTextIndex + 1) % this.thinkingTexts.length
      this.updateThinkingBubble(thinkingId, this.thinkingTexts[this.thinkingTextIndex])
    }, this.thinkingInterval)

    return thinkingId
  }

  /**
   * 更新 AI 思考气泡文案
   */
  updateThinkingBubble(thinkingId: number, content: string): void {
    const nextList: ChatMessage[] = this.chatList.map((item: ChatMessage): ChatMessage => {
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

    this.chatList = nextList
    this.scrollToBottom()
  }

  /**
   * 停止 AI 思考气泡轮播定时器
   */
  stopThinkingTimer(): void {
    if (this.thinkingTimer !== -1) {
      clearInterval(this.thinkingTimer)
      this.thinkingTimer = -1
    }
  }

  /**
   * 删除 AI 思考气泡
   */
  removeThinkingBubble(thinkingId: number): void {
    this.stopThinkingTimer()

    this.chatList = this.chatList.filter((item: ChatMessage): boolean => {
      return item.id !== thinkingId
    })

    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
  }

  /**
   * 用真实消息替换 AI 思考气泡
   */
  replaceThinkingBubble(thinkingId: number, messages: ChatMessage[]): void {
    this.stopThinkingTimer()

    const nextList: ChatMessage[] = this.chatList.filter((item: ChatMessage): boolean => {
      return item.id !== thinkingId
    })

    this.chatList = nextList.concat(messages)

    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
  }

  /**
   * 生成 ForEach key
   *
   * 关键点：
   * 普通消息 key 使用 id 即可。
   * thinking 气泡的 content 会轮播变化，所以 key 要加 content。
   * 否则 ArkUI 可能复用旧 ListItem，导致 UI 不刷新。
   */
  getMessageKey(item: ChatMessage): string {
    if (item.id === this.thinkingMessageId) {
      return `${item.id}-${item.content}`
    }

    return `${item.id}`
  }

  /**
   * 发送消息
   */
  async sendMessage(): Promise<void> {
    const content: string = this.inputValue.trim()

    if (!content || this.isSending || !this.isAuthReady) {
      return
    }

    this.isSending = true
    this.inputValue = ''

    const now: number = Date.now()

    const tempUserMessage: ChatMessage = {
      id: now,
      role: 'user',
      content: content,
      createTime: now
    }

    this.chatList = this.chatList.concat([tempUserMessage])
    await this.saveChatCache()
    this.scrollToBottom()

    const thinkingId: number = this.startThinkingBubble()
    const thinkingStartTime: number = Date.now()

    try {
      const requestParams: ChatRequest = {
        content: content
      }

      if (this.conversationId > 0) {
        requestParams.conversationId = this.conversationId
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
        await this.saveChatCache()
        this.scrollToBottom()
        return
      }

      this.conversationId = res.data.conversationId

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
      await this.saveChatCache()
      this.scrollToBottom()
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
      await this.saveChatCache()
      this.scrollToBottom()
    } finally {
      this.stopThinkingTimer()
      this.isSending = false
    }
  }

  build() {
    Column() {
      this.Header()
      this.MessageList()
      this.InputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }

  @Builder
  Header() {
    Row() {
      Column() {
        Text('聊天 Demo')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')

        if (globalAuthStore.userInfo !== null) {
          Text(`当前用户：${globalAuthStore.userInfo.nickname}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        } else {
          Text('未登录')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row() {
        Button('清空')
          .height(32)
          .fontSize(14)
          .enabled(this.chatList.length > 0 && !this.isSending)
          .onClick(() => {
            this.clearChatHistory()
          })

        Button('退出')
          .height(32)
          .fontSize(14)
          .margin({ left: 8 })
          .enabled(!this.isSending)
          .onClick(() => {
            this.logout()
          })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MessageList() {
    List({ scroller: this.listScroller }) {
      if (this.chatList.length === 0) {
        ListItem() {
          Column() {
            Text('暂无聊天记录')
              .fontSize(16)
              .fontColor('#999999')

            Text('输入内容后开始聊天')
              .fontSize(13)
              .fontColor('#BBBBBB')
              .margin({ top: 8 })
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }

      ForEach(this.chatList, (item: ChatMessage) => {
        ListItem() {
          Row() {
            if (item.role === 'user') {
              Blank()

              Text(item.content)
                .fontSize(16)
                .fontColor(Color.White)
                .backgroundColor('#1677FF')
                .borderRadius(10)
                .padding({
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: 8
                })
                .constraintSize({
                  maxWidth: '75%'
                })
            } else {
              Text(item.content)
                .fontSize(16)
                .fontColor('#333333')
                .backgroundColor(Color.White)
                .borderRadius(10)
                .padding({
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: 8
                })
                .constraintSize({
                  maxWidth: '75%'
                })

              Blank()
            }
          }
          .width('100%')
          .margin({ bottom: 12 })
          .alignItems(VerticalAlign.Top)
        }
      }, (item: ChatMessage) => this.getMessageKey(item))

      ListItem() {
        Row() {
          Blank()
        }
        .height(12)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: 12,
      bottom: 12
    })
  }

  @Builder
  InputBar() {
    Row() {
      TextInput({
        placeholder: '请输入内容',
        text: this.inputValue
      })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.White)
        .borderRadius(22)
        .padding({
          left: 14,
          right: 14
        })
        .enabled(!this.isSending && this.isAuthReady)
        .onChange((value: string) => {
          this.inputValue = value
        })

      Button(this.isSending ? '发送中' : '发送')
        .height(44)
        .margin({ left: 10 })
        .enabled(!this.isSending && this.isAuthReady)
        .onClick(() => {
          this.sendMessage()
        })
    }
    .width('100%')
    .height(64)
    .padding({
      left: 12,
      right: 12
    })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }
}