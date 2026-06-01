import { ChatMessage } from '../models/chatModel'

@ComponentV2
export struct ChatListComp {
  @Param historyMessage: ChatMessage[] = []
  @Param isLoading: boolean = false
  @Param responseMessage: string = ''
  private scroller: Scroller = new Scroller()

  // 消息列表或 responseMessage 变化时自动滚到底部
  @Monitor('historyMessage', 'responseMessage')
  onMessageChange() {
    this.scroller.scrollEdge(Edge.Bottom)
  }

  build() {
    List({ scroller: this.scroller, space: 12 }) {

      // 历史消息
      ForEach(this.historyMessage, (item: ChatMessage) => {
        ListItem() {
          this.MessageBubble(item.role, item.content)
        }
      }, (item: ChatMessage) => item.id)

      // 打字机效果：AI 正在输出内容
      if (this.responseMessage) {
        ListItem() {
          this.MessageBubble('assistant', this.responseMessage)
        }
      }

      // AI 加载气泡
      if (this.isLoading) {
        ListItem() {
          this.LoadingBubble()
        }
      }

    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
    .alignListItem(ListItemAlign.Start)
  }

  @Builder
  MessageBubble(role: string, content: string) {
    Row() {
      if (role === 'assistant') {
        Text(content)
          .padding(12)
          .backgroundColor('#F0F0F0')
          .borderRadius({ topLeft: 4, topRight: 12, bottomLeft: 12, bottomRight: 12 })
          .constraintSize({ maxWidth: '75%' })
        Blank()
      } else {
        Blank()
        Text(content)
          .padding(12)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .borderRadius({ topLeft: 12, topRight: 4, bottomLeft: 12, bottomRight: 12 })
          .constraintSize({ maxWidth: '75%' })
      }
    }
    .width('100%')
  }

  @Builder
  LoadingBubble() {
    Row() {
      Text('...')
        .padding(12)
        .backgroundColor('#F0F0F0')
        .borderRadius({ topLeft: 4, topRight: 12, bottomLeft: 12, bottomRight: 12 })
      Blank()
    }
    .width('100%')
  }
}
