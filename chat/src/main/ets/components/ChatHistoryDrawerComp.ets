import { ChatHistoryController } from '../controller/ChatHistoryController'
import { ChatSession } from '../models/chatModel'
import { ThemeState, getThemeState, LogUtil } from 'common'

/**
 * 聊天历史右侧抽屉。
 *
 * 仅负责历史列表的展示和操作意图上报；当前会话的切换、新建与重置
 * 统一由 ChatTabComp 持有的 ChatSessionController 完成。
 */
@ComponentV2
export struct ChatHistoryDrawerComp {
  @Param visible: boolean = false
  @Param isGenerating: boolean = false
  @Param operationPending: boolean = false
  @Param currentSessionId: string = ''

  @Event onClose: () => void = () => {}
  @Event onSelectSession: (sessionId: string) => Promise<void> = (_sessionId: string) => Promise.resolve()
  @Event onNewSession: () => void = () => {}
  @Event onSessionDeleted: (sessionId: string) => void = (_sessionId: string) => {}
  @Event onOperationStateChange: (pending: boolean) => void = (_pending: boolean) => {}

  @Local sessions: ChatSession[] = []
  @Local theme: ThemeState = getThemeState()
  @Local isOperating: boolean = false

  private controller: ChatHistoryController = new ChatHistoryController()

  aboutToAppear(): void {
    this.loadData()
  }

  @Monitor('visible')
  onVisibleChange(): void {
    if (this.visible) {
      this.loadData()
    }
  }

  @Monitor('operationPending')
  onOperationPendingChange(): void {
    if (this.visible && !this.operationPending) {
      this.loadData()
    }
  }

  private async loadData(): Promise<void> {
    this.sessions = await this.controller.loadData()
  }

  private showHint(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1800
      })
    } catch (error) {
      LogUtil.e('ChatHistoryDrawerComp', 'show toast failed: ' + JSON.stringify(error))
    }
  }

  private actionsLocked(): boolean {
    if (this.isGenerating) {
      this.showHint('AI 正在生成回复，请先停止或等待完成')
      return true
    }
    if (this.operationPending || this.isOperating) {
      this.showHint('正在处理会话，请稍候')
      return true
    }
    return false
  }

  private requestClose(): void {
    if (this.operationPending || this.isOperating) {
      this.showHint('正在处理会话，请稍候')
      return
    }
    this.onClose()
  }

  private requestNewSession(): void {
    if (this.actionsLocked()) {
      return
    }
    this.onNewSession()
  }

  private async requestSelectSession(sessionId: string): Promise<void> {
    if (this.actionsLocked()) {
      return
    }
    if (sessionId === this.currentSessionId) {
      this.requestClose()
      return
    }
    this.isOperating = true
    try {
      await this.onSelectSession(sessionId)
    } finally {
      this.isOperating = false
    }
  }

  private async requestDeleteSession(sessionId: string): Promise<void> {
    if (this.actionsLocked()) {
      return
    }
    this.isOperating = true
    this.onOperationStateChange(true)
    try {
      const updatedSessions = await this.controller.deleteSession(sessionId, this.sessions)
      if (updatedSessions === null) {
        this.showHint('删除失败，请稍后重试')
        return
      }
      this.sessions = updatedSessions
      this.onSessionDeleted(sessionId)
    } finally {
      this.isOperating = false
      this.onOperationStateChange(false)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .opacity(this.visible ? 1 : 0)
        .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.None)
        .onClick(() => {
          this.requestClose()
        })

      Column() {
        Row() {
          Text('历史会话')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)

          Blank()

          Text('+ 新建')
            .fontSize(14)
            .fontColor(this.isGenerating || this.operationPending || this.isOperating
              ? this.theme.textTertiary : this.theme.primary)
            .padding({ left: 8, right: 8, top: 8, bottom: 8 })
            .onClick(() => {
              this.requestNewSession()
            })

          Text('×')
            .fontSize(28)
            .fontColor(this.theme.textSecondary)
            .padding({ left: 10, right: 4, top: 4, bottom: 4 })
            .onClick(() => {
              this.requestClose()
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 18, right: 12 })
        .backgroundColor(this.theme.surface)
        .border({ width: { bottom: 0.5 }, color: this.theme.divider })

        if (this.sessions.length === 0) {
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
        } else {
          List() {
            ForEach(this.sessions, (session: ChatSession) => {
              ListItem() {
                Row({ space: 12 }) {
                  Text(session.title.length > 0 ? session.title.charAt(0) : '新')
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
                      Text(session.title.length > 0 ? session.title : '新对话')
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.theme.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)

                      Text(this.controller.formatTime(session.updateTime))
                        .fontSize(11)
                        .fontColor(this.theme.textTertiary)
                    }
                    .width('100%')

                    Text(session.preview.length > 0 ? session.preview : '暂无回复')
                      .fontSize(13)
                      .fontColor(this.theme.textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (session.id === this.currentSessionId) {
                    Text('当前')
                      .fontSize(10)
                      .fontColor(this.theme.primary)
                  }
                }
                .width('100%')
                .padding({ left: 14, right: 12, top: 14, bottom: 14 })
                .backgroundColor(session.id === this.currentSessionId ? this.theme.infoBg : this.theme.surface)
              }
              .swipeAction({ end: this.deleteButton(session.id) })
              .onClick(() => {
                this.requestSelectSession(session.id)
              })
            }, (session: ChatSession) => session.id)
          }
          .width('100%')
          .layoutWeight(1)
          .divider({
            strokeWidth: 0.5,
            color: this.theme.divider,
            startMargin: 68
          })
          .backgroundColor(this.theme.bg)
        }
      }
      .width('80%')
      .height('100%')
      .backgroundColor(this.theme.bg)
      .shadow({ radius: 24, color: this.theme.drawerShadowColor, offsetX: -6, offsetY: 0 })
      .translate({ x: this.visible ? 0 : '100%' })
      .hitTestBehavior(this.visible ? HitTestMode.Block : HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .opacity(this.visible ? 1 : 0)
    .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.BLOCK_DESCENDANTS)
  }

  @Builder
  deleteButton(sessionId: string) {
    Button('删除')
      .width(72)
      .height('100%')
      .fontSize(14)
      .backgroundColor(this.isGenerating || this.operationPending || this.isOperating
        ? this.theme.disabledBg : this.theme.danger)
      .fontColor(this.theme.onDanger)
      .borderRadius(0)
      .onClick(() => {
        this.requestDeleteSession(sessionId)
      })
  }
}
