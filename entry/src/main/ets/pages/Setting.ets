import { HMRouter } from '@hadss/hmrouter'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

import { RouteConstants } from '../constants/RouteConstants'
import { globalTabState } from '../stores/TabState'
import { sendChatMessage, ChatMessageDTO } from '../api/ChatApi'
import { ChatMessage } from '../models/ChatModel'
import { ChatStorage } from '../utils/ChatStorage'

@HMRouter({ pageUrl: RouteConstants.SETTING })
@ComponentV2
export struct Setting {
  // 滚动示例：这里用 Scroller 控制 List 滚动到底部
  private listScroller: Scroller = new Scroller()

  @Local inputValue: string = ''
  @Local chatList: ChatMessage[] = []
  @Local isSending: boolean = false
  @Local conversationId: number = 0

  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.SETTING)

    // 键盘弹起时，页面整体 resize，避免底部输入框被键盘遮挡
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)

    // 页面进入时读取本地聊天缓存
    this.loadChatCache()
  }

  /**
   * 页面进入时读取本地缓存
   *
   * 注意：
   * 1. aboutToAppear 保持 void
   * 2. 真正的异步逻辑放到单独方法里
   * 3. 读取到缓存后恢复 conversationId 和 chatList
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
   *
   * 保存内容：
   * 1. conversationId
   * 2. chatList
   */
  async saveChatCache(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    await ChatStorage.saveChatCache(context, this.conversationId, this.chatList)
  }

  /**
   * 清空聊天历史
   *
   * 注意：
   * 1. 页面 chatList 要清空
   * 2. conversationId 也要重置
   * 3. 本地 Preferences 缓存也要删除
   */
  async clearChatHistory(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext

    this.chatList = []
    this.conversationId = 0

    await ChatStorage.clearChatCache(context)
  }

  /**
   * 滚动到底部
   *
   * 注意：
   * 1. chatList 变化后，List 需要一点时间完成重新渲染
   * 2. 所以这里用 setTimeout 延迟执行滚动
   * 3. this.chatList.length 对应底部占位 ListItem 的索引
   */
  scrollToBottom(): void {
    setTimeout(() => {
      this.listScroller.scrollToIndex(this.chatList.length)
    }, 50)
  }

  /**
   * 发送消息
   *
   * 当前流程：
   * 1. 读取输入框内容
   * 2. 先把用户消息追加到页面
   * 3. 保存本地缓存
   * 4. 调用 Next.js 后端接口 POST /api/chat
   * 5. 拿到后端返回的 assistant 消息
   * 6. 把 assistant 消息追加到页面
   * 7. 再次保存本地缓存
   */
  async sendMessage(): Promise<void> {
    const content = this.inputValue.trim()

    if (!content || this.isSending) {
      return
    }

    this.isSending = true
    this.inputValue = ''

    const now = Date.now()

    const tempUserMessage: ChatMessage = {
      id: now,
      role: 'user',
      content,
      createTime: now
    }

    this.chatList = this.chatList.concat([tempUserMessage])
    await this.saveChatCache()
    this.scrollToBottom()

    try {
      const res = await sendChatMessage({
        conversationId: this.conversationId || undefined,
        content
      })

      if (res.code !== 0) {
        const failMessage: ChatMessage = {
          id: Date.now(),
          role: 'assistant',
          content: res.message || '后端返回异常，请稍后重试。',
          createTime: Date.now()
        }

        this.chatList = this.chatList.concat([failMessage])
        await this.saveChatCache()
        this.scrollToBottom()
        return
      }

      this.conversationId = res.data.conversationId

      const assistantMessages: ChatMessage[] = res.data.messages
        .filter((item: ChatMessageDTO) => item.role === 'assistant')
        .map((item: ChatMessageDTO) => {
          const message: ChatMessage = {
            id: item.id,
            role: item.role,
            content: item.content,
            createTime: item.createTime
          }

          return message
        })

      this.chatList = this.chatList.concat(assistantMessages)
      await this.saveChatCache()
      this.scrollToBottom()
    } catch (error) {
      const errorMessage: ChatMessage = {
        id: Date.now(),
        role: 'assistant',
        content: '请求后端失败，请检查 Next.js 服务是否启动，以及接口地址是否正确。',
        createTime: Date.now()
      }

      this.chatList = this.chatList.concat([errorMessage])
      await this.saveChatCache()
      this.scrollToBottom()
    } finally {
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
      Text('聊天 Demo')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#222222')

      Blank()

      Button('清空')
        .height(32)
        .fontSize(14)
        .enabled(this.chatList.length > 0 && !this.isSending)
        .onClick(() => {
          this.clearChatHistory()
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MessageList() {
    List({ scroller: this.listScroller }) {
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
      }, (item: ChatMessage) => `${item.id}`)

      // 底部占位，防止最后一条消息贴着输入框
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
        .enabled(!this.isSending)
        .onChange((value: string) => {
          this.inputValue = value
        })

      Button(this.isSending ? '发送中' : '发送')
        .height(44)
        .margin({ left: 10 })
        .enabled(!this.isSending)
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