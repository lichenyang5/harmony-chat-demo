import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'

@ComponentV2
export struct ChatListComp {
  @Param @Require vm: ChatViewModel
  @Local displayText: string = ''
  private fullText: string = ''
  private typeIndex: number = 0
  private scroller: Scroller = new Scroller()

  // 监听 controller 设置的完整响应，触发打字机
  @Monitor('vm.pendingResponse')
  onPendingResponse() {
    if (!this.vm.pendingResponse) {
      return
    }
    this.fullText = this.vm.pendingResponse
    this.displayText = ''
    this.typeIndex = 0
    this.typeNext()
  }

  @Monitor('vm.historyMessage')
  onNewMessage() {
    this.scroller.scrollEdge(Edge.Bottom)
  }

  private typeNext(): void {
    if (this.typeIndex >= this.fullText.length) {
      // 打完：推入历史记录，清空临时状态
      const aiMessage = new ChatMessage()
      aiMessage.id = Date.now().toString()
      aiMessage.role = 'assistant'
      aiMessage.content = this.fullText
      aiMessage.createTime = Date.now()
      this.vm.historyMessage.push(aiMessage)
      this.displayText = ''
      this.vm.pendingResponse = ''
      return
    }
    this.displayText += this.fullText[this.typeIndex]
    this.typeIndex++
    setTimeout(() => { this.typeNext() }, 80)
  }

  build() {
    List({ scroller: this.scroller, space: 12 }) {

      ForEach(this.vm.historyMessage, (item: ChatMessage) => {
        ListItem() {
          this.MessageBubble(item.role, item.content)
        }
      }, (item: ChatMessage) => item.id)

      // 打字机气泡
      if (this.displayText) {
        ListItem() {
          this.MessageBubble('assistant', this.displayText)
        }
      }

      // 加载气泡
      if (this.vm.isLoading) {
        ListItem() {
          this.LoadingBubble()
        }
      }

    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
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
