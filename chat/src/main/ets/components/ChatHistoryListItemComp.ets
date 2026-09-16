import { ChatSession } from '../models/chatModel'
import { ThemeState, getThemeState } from 'common'

/**
 * 单条历史会话的纯展示组件。
 *
 * 本组件拥有列表行、当前标记和左滑删除按钮的视觉，只上报选择与删除意图。
 * 生成中、保存中等业务锁判断及 Toast 仍由 ChatHistoryDrawerComp 统一处理。
 */
@ComponentV2
export struct ChatHistoryListItemComp {
  @Param @Require session: ChatSession
  @Param currentSessionId: string = ''
  @Param formattedTime: string = ''
  @Param actionsDisabled: boolean = false

  @Event onSelect: (sessionId: string) => void = (_sessionId: string) => {}
  @Event onDelete: (sessionId: string) => void = (_sessionId: string) => {}

  @Local theme: ThemeState = getThemeState()

  build() {
    ListItem() {
      Row({ space: 12 }) {
        Text(this.session.title.length > 0 ? this.session.title.charAt(0) : '新')
          .width(42)
          .height(42)
          .fontSize(17)
          .fontColor(this.theme.onPrimary)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.theme.primary)
          .borderRadius(21)
          .flexShrink(0)

        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(this.session.title.length > 0 ? this.session.title : '新对话')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(this.formattedTime)
              .fontSize(11)
              .fontColor(this.theme.textTertiary)
          }
          .width('100%')

          Text(this.session.preview.length > 0 ? this.session.preview : '暂无回复')
            .fontSize(13)
            .fontColor(this.theme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.session.id === this.currentSessionId) {
          Text('当前')
            .fontSize(10)
            .fontColor(this.theme.primary)
        }
      }
      .width('100%')
      .padding({ left: 14, right: 12, top: 14, bottom: 14 })
      .backgroundColor(this.session.id === this.currentSessionId ? this.theme.infoBg : this.theme.surface)
    }
    .swipeAction({ end: this.deleteButton() })
    .onClick(() => {
      this.onSelect(this.session.id)
    })
  }

  @Builder
  private deleteButton() {
    Button('删除')
      .width(72)
      .height('100%')
      .fontSize(14)
      .backgroundColor(this.actionsDisabled ? this.theme.disabledBg : this.theme.danger)
      .fontColor(this.theme.onDanger)
      .borderRadius(0)
      .onClick(() => {
        this.onDelete(this.session.id)
      })
  }
}
