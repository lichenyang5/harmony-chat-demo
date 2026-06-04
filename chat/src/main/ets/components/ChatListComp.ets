import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ThemeState, getThemeState } from 'common'

/**
 * 单条气泡子组件
 *
 * 重点：
 * 1. 使用 @ComponentV2 子组件接收 ChatMessage。
 * 2. msg.content 做空值防御，避免历史数据异常时 undefined.length 崩溃。
 * 3. AI 占位消息 content 为空时显示“AI 思考中...”，等流式 chunk 到达后自动替换。
 */
@ComponentV2
struct MessageBubble {
  @Param @Require msg: ChatMessage
  @Local theme: ThemeState = getThemeState()

  private getSafeContent(): string {
    if (this.msg.content) {
      return this.msg.content
    }
    return ''
  }

  build() {
    Row() {
      if (this.msg.role === 'assistant') {
        Text(this.getSafeContent().length > 0 ? this.getSafeContent() : 'AI 思考中...')
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .padding(12)
          .backgroundColor(this.theme.assistantBubbleBg)
          .borderRadius({
            topLeft: 4,
            topRight: 12,
            bottomLeft: 12,
            bottomRight: 12
          })
          .constraintSize({ maxWidth: '75%' })

        Blank()
      } else {
        Blank()

        Text(this.getSafeContent())
          .fontSize(15)
          .fontColor(this.theme.onPrimary)
          .padding(12)
          .backgroundColor(this.theme.userBubbleBg)
          .borderRadius({
            topLeft: 12,
            topRight: 4,
            bottomLeft: 12,
            bottomRight: 12
          })
          .constraintSize({ maxWidth: '75%' })
      }
    }
    .width('100%')
  }
}

@ComponentV2
export struct ChatListComp {
  @Param @Require vm: ChatViewModel

  @Local theme: ThemeState = getThemeState()

  private scroller: Scroller = new Scroller()

  @Monitor('vm.historyMessage')
  onHistoryChange(): void {
    this.scrollToBottom()
  }

  private scrollToBottom(): void {
    try {
      this.scroller.scrollEdge(Edge.Bottom)
    } catch (_) {
    }
  }

  build() {
    List({ scroller: this.scroller, space: 12 }) {
      ForEach(this.vm.historyMessage ? this.vm.historyMessage : [], (item: ChatMessage) => {
        ListItem() {
          MessageBubble({ msg: item })
        }
      }, (item: ChatMessage) => {
        if (item.id) {
          return item.id
        }
        return `${item.createTime}_${item.role}`
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.theme.bg)
  }
}