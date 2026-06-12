import { ChatMessage, AgentCard, PickupCard, TripCard } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatController } from '../controller/ChatController'
import { MessageStatus, isTerminal } from '../models/MessageStatus'
import { ChatRole, ChatText } from '../constants/ChatConstants'
import { ThemeState, getThemeState } from 'common'
import { PickupConfirmCardComp } from './PickupConfirmCardComp'
import { ConfirmTripCardComp } from './ConfirmTripCardComp'

/**
 * 单条气泡子组件
 *
 * 渲染完全由 msg.status 驱动（单一状态机）：
 * - user：SENDING 转圈 / FAILED 红叹号可点重发 / 其余正常气泡
 * - assistant：THINKING 思考中 / STREAMING 正文 + 光标 / STOPPED 独立停止条 /
 *   FAILED 错误提示 / 终态末尾「重新生成」
 *
 * ArkUI V2 注意：所有响应式字段（this.msg.status / content / card）都在
 * build 顶层直接读，不抽进 @Builder 参数，否则丢依赖追踪。
 */
@ComponentV2
struct MessageBubble {
  @Param @Require msg: ChatMessage
  @Param @Require controller: ChatController
  /**
   * 传入整个 vm，让气泡自己判断「我是不是最后一条」。
   * 不在父组件算好用 @Param isLast 传进来——ForEach 复用 key 不变的旧项时不会重跑
   * item builder，传进来的 isLast 会变陈旧；在 build 里读 vm.historyMessage（@Trace）
   * 才能在新消息 push 时让旧的最后一条重渲染、收起「重新生成」。
   */
  @Param @Require vm: ChatViewModel

  @Local theme: ThemeState = getThemeState()

  /** 失败提示：优先用运行时写入的 errorHint，历史读回为空时兜底通用文案 */
  private failedHint(): string {
    return this.msg.errorHint && this.msg.errorHint.length > 0
      ? this.msg.errorHint
      : ChatText.ERR_NETWORK
  }

  /** 我是不是列表最后一条（读 vm.historyMessage 建立依赖，结构变化时重算） */
  private isLastMessage(): boolean {
    const list = this.vm.historyMessage
    if (!list || list.length === 0) {
      return false
    }
    const last = list[list.length - 1]
    return last !== undefined && last.id === this.msg.id
  }

  build() {
    Row({ space: 8 }) {
      if (this.msg.role === ChatRole.ASSISTANT) {
        // ── 助理消息 ──────────────────────────────────────────────
        Column({ space: 8 }) {
          if (this.msg.status === MessageStatus.THINKING) {
            // 思考中：等待首个 token
            Row({ space: 8 }) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(this.theme.primary)
              Text(ChatText.THINKING)
                .fontSize(15)
                .fontColor(this.theme.textSecondary)
            }
          } else if (this.msg.content.length > 0) {
            // 正文：流式中追加一个光标 Span（不拼进 content，保持正文干净）
            Text() {
              Span(this.msg.content)
              Span(this.msg.status === MessageStatus.STREAMING ? '  ▌' : '')
                .fontColor(this.theme.primary)
            }
            .fontSize(15)
            .fontColor(this.theme.textPrimary)
            .constraintSize({ maxWidth: '85%' })
          } else if (this.msg.status === MessageStatus.DONE) {
            // 历史读回内容缺失的兜底
            Text(ChatText.CONTENT_MISSING)
              .fontSize(15)
              .fontColor(this.theme.textTertiary)
          }

          // 停止：独立状态（分割线 + 文案），不在正文里拼 [已停止]
          if (this.msg.status === MessageStatus.STOPPED) {
            Text(ChatText.STOPPED)
              .fontSize(12)
              .fontColor(this.theme.textTertiary)
              .padding({ top: 4 })
              .border({ width: { top: 0.5 }, color: this.theme.divider })
          }

          // 失败：错误提示
          if (this.msg.status === MessageStatus.FAILED) {
            Text(this.failedHint())
              .fontSize(13)
              .fontColor(this.theme.danger)
          }

          // 卡片：按 card.type 分发（响应式字段在 build 顶层读）
          if (this.msg.card !== null) {
            if ((this.msg.card as AgentCard).type === 'trip_confirm') {
              ConfirmTripCardComp({ card: this.msg.card as Object as TripCard })
            } else {
              PickupConfirmCardComp({ card: this.msg.card as Object as PickupCard })
            }
          }

          // 重新生成：仅最后一条且为终态的助理消息
          if (this.isLastMessage() && isTerminal(this.msg.status)) {
            Row({ space: 4 }) {
              Text('⟳ ' + ChatText.REGENERATE)
                .fontSize(13)
                .fontColor(this.theme.textSecondary)
            }
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.theme.secondaryButtonBg)
            .borderRadius(14)
            .onClick(() => {
              this.controller.regenerate(this.msg)
            })
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
      } else {
        // ── 用户消息 ──────────────────────────────────────────────
        Blank()

        // 发送中：小转圈
        if (this.msg.status === MessageStatus.SENDING) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(this.theme.textTertiary)
        }

        // 失败：红叹号，点一下重发
        if (this.msg.status === MessageStatus.FAILED) {
          Text('!')
            .width(22)
            .height(22)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.onDanger)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.theme.danger)
            .borderRadius(11)
            .onClick(() => {
              this.controller.resendMessage(this.msg)
            })
        }

        Text(this.msg.content ? this.msg.content : '')
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
  @Param @Require controller: ChatController

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
          MessageBubble({
            msg: item,
            controller: this.controller,
            vm: this.vm
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
