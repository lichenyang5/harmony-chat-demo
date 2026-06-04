import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ThemeState, getThemeState } from 'common'

@ComponentV2
export struct ChatListComp {
  @Param @Require vm: ChatViewModel

  @Local theme: ThemeState = getThemeState()

  private scroller: Scroller = new Scroller()

  // 历史消息变化：滚到底（新消息推入时）
  @Monitor('vm.historyMessage')
  onNewMessage() {
    this.scroller.scrollEdge(Edge.Bottom)
  }

  // 流式内容追加：滚到底（每个 chunk 来时）
  @Monitor('vm.streamingContent')
  onStreamingUpdate() {
    if (this.vm.streamingContent.length > 0) {
      this.scroller.scrollEdge(Edge.Bottom)
    }
  }

  build() {
    List({ scroller: this.scroller, space: 12 }) {
      // 已完成的历史消息
      ForEach(this.vm.historyMessage, (item: ChatMessage) => {
        ListItem() {
          this.MessageBubble(item.role, item.content)
        }
      }, (item: ChatMessage) => item.id)

      // 正在流式生成的 AI 气泡：直接展示 streamingContent
      // 每收到一个 chunk，@Trace 触发重渲染，文本自然往后续
      if (this.vm.streamingContent.length > 0) {
        ListItem() {
          this.MessageBubble('assistant', this.vm.streamingContent)
        }
      }

      // Loading：网络请求已发但还没收到首个 chunk 时显示
      if (this.vm.isLoading && this.vm.streamingContent.length === 0) {
        ListItem() {
          this.LoadingBubble()
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.theme.bg)
  }

  @Builder
  MessageBubble(role: string, content: string) {
    Row() {
      if (role === 'assistant') {
        Text(content)
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

        Text(content)
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

  @Builder
  LoadingBubble() {
    Row() {
      Text('AI 思考中...')
        .fontSize(14)
        .fontColor(this.theme.textSecondary)
        .padding(12)
        .backgroundColor(this.theme.loadingBubbleBg)
        .borderRadius({
          topLeft: 4,
          topRight: 12,
          bottomLeft: 12,
          bottomRight: 12
        })

      Blank()
    }
    .width('100%')
  }
}
