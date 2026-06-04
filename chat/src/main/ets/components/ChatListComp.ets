import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ThemeState, getThemeState } from 'common'

/**
 * 单条气泡子组件
 *
 * 必须是 @ComponentV2 子组件而不是 @Builder：
 * @Builder 是函数，参数值变化无法触发重渲染；
 * @ComponentV2 + @Param 接收 ChatMessage 对象后，
 * 读 msg.content 时 @Trace 能正确追踪，
 * 流式追加 content 时这个子组件自动重跑 build()。
 */
@ComponentV2
struct MessageBubble {
  @Param @Require msg: ChatMessage
  @Local theme: ThemeState = getThemeState()

  build() {
    Row() {
      if (this.msg.role === 'assistant') {
        // 防御：content 可能为 undefined（历史数据 / 序列化丢失），用 && 短路
        Text(this.msg.content && this.msg.content.length > 0 ? this.msg.content : '...')
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

        Text(this.msg.content ?? '')
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

  // 历史消息数量变化：滚到底
  @Monitor('vm.historyMessage')
  onHistoryChange() {
    this.scroller.scrollEdge(Edge.Bottom)
  }

  build() {
    List({ scroller: this.scroller, space: 12 }) {
      ForEach(this.vm.historyMessage, (item: ChatMessage) => {
        ListItem() {
          MessageBubble({ msg: item })
        }
      }, (item: ChatMessage) => item.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.theme.bg)
  }
}
