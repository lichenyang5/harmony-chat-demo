import { HMRouter } from '@hadss/hmrouter'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { RouteConstants } from '../constants/RouteConstants'
import { globalTabState } from '../stores/TabState'

interface ChatItem {
  id: number
  type: 'user' | 'ai'
  content: string
}

@HMRouter({ pageUrl: RouteConstants.SETTING })
@ComponentV2
export struct Setting {
  private typingTimer: number = -1
  // 滚动示例，有很多滚动方法，这里用到的Index索引滚动到列表的指定元素
  private listScroller: Scroller = new Scroller()
  private nextId: number = 1

  @Local inputValue: string = ''
  @Local chatList: ChatItem[] = []
  @Local isSending: boolean = false

  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.SETTING)

    // 键盘弹起时，页面整体 resize，避免底部输入框被键盘遮挡
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
  }
  aboutToDisappear(): void {
    if (this.typingTimer !== -1) {
      clearInterval(this.typingTimer)
      this.typingTimer = -1
    }
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
   * 模拟 AI 接口
   *
   * 后面真正接接口时，可以把这里替换成 request 请求。
   */
  mockAskAi(question: string): void {
    const fullText: string = `你刚才说的是：${question}。这是一个模拟 AI 回复，当前正在使用打字机效果逐字输出。`

    const aiItem: ChatItem = {
      id: this.nextId++,
      type: 'ai',
      content: 'AI 正在思考...'
    }

    this.chatList = this.chatList.concat([aiItem])
    this.scrollToBottom()

    let currentIndex: number = 0

    setTimeout(() => {
      this.typingTimer = setInterval(() => {
        currentIndex++

        const currentText: string = fullText.slice(0, currentIndex)

        this.chatList = this.chatList.map((item: ChatItem) => {
          if (item.id === aiItem.id) {
            return {
              id: item.id,
              type: item.type,
              content: currentText
            }
          }

          return item
        })

        this.scrollToBottom()

        if (currentIndex >= fullText.length) {
          clearInterval(this.typingTimer)
          this.typingTimer = -1
          this.isSending = false
        }
      }, 60)
    }, 500)
  }

  sendMsg(): void {
    const text: string = this.inputValue.trim()

    if (text === '') {
      return
    }

    if (this.isSending) {
      return
    }

    const userItem: ChatItem = {
      id: this.nextId++,
      type: 'user',
      content: text
    }

    this.chatList = this.chatList.concat([userItem])
    this.inputValue = ''
    this.isSending = true

    this.scrollToBottom()
    this.mockAskAi(text)
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
      ForEach(this.chatList, (item: ChatItem) => {
        ListItem() {
          Row() {
            if (item.type === 'user') {
              Blank()

              Text(item.content)
                .fontSize(16)
                .fontColor(Color.White)
                .backgroundColor('#1677FF')
                .borderRadius(10)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            } else {
              Text(item.content)
                .fontSize(16)
                .fontColor('#333333')
                .backgroundColor(Color.White)
                .borderRadius(10)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })

              Blank()
            }
          }
          .width('100%')
          .margin({ bottom: 12 })
        }
      }, (item: ChatItem) => `${item.id}-${item.content}`)

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
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
  }

  @Builder
  InputBar() {
    Row() {
      TextInput({ placeholder: '请输入内容', text: this.inputValue })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.White)
        .borderRadius(22)
        .padding({ left: 14, right: 14 })
        .enabled(!this.isSending)
        .onChange((value: string) => {
          this.inputValue = value
        })

      Button(this.isSending ? '发送中' : '发送')
        .height(44)
        .margin({ left: 10 })
        .enabled(!this.isSending)
        .onClick(() => {
          this.sendMsg()
        })
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }
}