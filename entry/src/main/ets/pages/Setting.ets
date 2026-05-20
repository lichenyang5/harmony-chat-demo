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
  private listScroller: Scroller = new Scroller()
  @Local inputValue: string = ''
  @Local chatList: ChatItem[] = []

  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.SETTING)
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
  }

  sendMsg(): void {
    const text: string = this.inputValue.trim()

    if (text === '') {
      return
    }

    const now: number = Date.now()

    const userItem: ChatItem = {
      id: now,
      type: 'user',
      content: text
    }

    const aiItem: ChatItem = {
      id: now + 1,
      type: 'ai',
      content: '你好'
    }

    this.chatList = this.chatList.concat([userItem, aiItem])
    this.inputValue = ''

    setTimeout(() => {
      this.listScroller.scrollToIndex(this.chatList.length)
    }, 50)
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
    .padding({
      left: 16,
      right: 16
    })
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
                .padding({
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: 8
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

              Blank()
            }
          }
          .width('100%')
          .margin({
            bottom: 12
          })
        }
      }, (item: ChatItem) => item.id.toString())

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
        .onChange((value: string) => {
          this.inputValue = value
        })

      Button('发送')
        .height(44)
        .margin({
          left: 10
        })
        .onClick(() => {
          this.sendMsg()
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