import { ThemeState, getThemeState } from 'common'

/**
 * 历史会话抽屉的空状态视图。
 *
 * 本组件只保留空列表的视觉，不加载数据，也不处理新建会话动作。
 */
@ComponentV2
export struct ChatHistoryStatusComp {
  @Local theme: ThemeState = getThemeState()

  build() {
    Column({ space: 12 }) {
      Text('○')
        .fontSize(44)
        .fontColor(this.theme.textTertiary)

      Text('暂无对话记录')
        .fontSize(15)
        .fontColor(this.theme.textTertiary)

      Text('点击右上角新建会话开始聊天')
        .fontSize(13)
        .fontColor(this.theme.textPlaceholder)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme.bg)
  }
}
