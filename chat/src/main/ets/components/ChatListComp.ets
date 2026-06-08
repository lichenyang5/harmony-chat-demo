import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ThemeState, getThemeState } from 'common'
import { PickupConfirmCardComp } from './PickupConfirmCardComp'

/**
 * 单条气泡子组件
 */
@ComponentV2
struct MessageBubble {
  @Param @Require msg: ChatMessage
  @Param isThinking: boolean = false

  @Local theme: ThemeState = getThemeState()

  private getSafeContent(): string {
    if (this.msg.content) {
      return this.msg.content
    }

    return ''
  }

  private getAssistantText(): string {
    const content = this.getSafeContent()

    if (content.length > 0) {
      return content
    }

    if (this.isThinking) {
      return 'AI 思考中...'
    }

    return '该条回复内容未保存完整'
  }

  build() {
    Row() {
      if (this.msg.role === 'assistant') {
        Column({ space: 8 }) {
          // AI 文本直接打印在列表背景上：无气泡背景、无圆角、无 padding
          Text(this.getAssistantText())
            .fontSize(15)
            .fontColor(this.theme.textPrimary)
            .constraintSize({ maxWidth: '85%' })

          // 后端 done 帧附带 card → 在文本气泡下方追加卡片占位
          if (this.msg.card !== null) {
            PickupConfirmCardComp({ card: this.msg.card! })
          }
        }
        .alignItems(HorizontalAlign.Start)

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

  /**
   * 判断当前 assistant 空消息是不是“正在生成中的最后一条”
   *
   * 只有满足：
   * 1. vm.isLoading 为 true
   * 2. 当前消息是 assistant
   * 3. 当前消息 content 为空
   * 4. 当前消息是列表最后一条
   *
   * 才显示 AI 思考中。
   */
  private isLastLiveThinking(item: ChatMessage): boolean {
    if (!this.vm.isLoading) {
      return false
    }

    if (item.role !== 'assistant') {
      return false
    }

    const content = item.content ? item.content : ''

    if (content.length > 0) {
      return false
    }

    if (!this.vm.historyMessage || this.vm.historyMessage.length === 0) {
      return false
    }

    const last: ChatMessage = this.vm.historyMessage[this.vm.historyMessage.length - 1]

    if (!last) {
      return false
    }

    return last.id === item.id
  }

  build() {
    List({ scroller: this.scroller, space: 12 }) {
      ForEach(this.vm.historyMessage ? this.vm.historyMessage : [], (item: ChatMessage) => {
        ListItem() {
          MessageBubble({
            msg: item,
            isThinking: this.isLastLiveThinking(item)
          })
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