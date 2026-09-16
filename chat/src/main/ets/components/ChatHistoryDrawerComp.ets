import { ChatHistoryController } from '../controller/ChatHistoryController'
import { ChatSession } from '../models/chatModel'
import { ChatHistoryListItemComp } from './ChatHistoryListItemComp'
import { ChatHistoryStatusComp } from './ChatHistoryStatusComp'
import { ThemeState, getThemeState, LogUtil } from 'common'

/**
 * 聊天历史右侧抽屉的业务编排容器。
 *
 * 本组件负责加载列表、操作锁、Toast、删除落库和事件回传；单条会话与空状态
 * 的视觉交给子组件。当前会话切换、新建与重置仍由 ChatTabComp 统一完成。
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

  /** 抽屉自己的列表快照；删除成功后用不可变过滤结果立即刷新。 */
  @Local sessions: ChatSession[] = []
  @Local theme: ThemeState = getThemeState()
  /** 防止抽屉内部的选择或删除动作并发执行。 */
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

  /**
   * 统一判断会话动作是否可执行。子组件只发出意图，避免每个列表项重复维护
   * 生成中、页面保存中和抽屉操作中的三套锁状态。
   */
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
          ChatHistoryStatusComp()
        } else {
          List() {
            ForEach(this.sessions, (session: ChatSession) => {
              ChatHistoryListItemComp({
                session: session,
                currentSessionId: this.currentSessionId,
                formattedTime: this.controller.formatTime(session.updateTime),
                actionsDisabled: this.isGenerating || this.operationPending || this.isOperating,
                onSelect: (sessionId: string) => {
                  this.requestSelectSession(sessionId)
                },
                onDelete: (sessionId: string) => {
                  this.requestDeleteSession(sessionId)
                }
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
}
