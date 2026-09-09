import { KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ChatController } from '../controller/ChatController'
import { ChatSessionController } from '../controller/ChatSessionController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from './ChatListComp'
import { ChatInputComp } from './ChatInputComp'
import { ChatHistoryDrawerComp } from './ChatHistoryDrawerComp'
import { WindowUtil, ThemeState, getThemeState, KeyboardController, LogUtil } from 'common'

/**
 * 聊天 Tab 组件（嵌入 HomePage 的 Tab 容器中）。
 *
 * 职责：聊天总容器、历史抽屉开关、消息列表、输入框和状态监听。
 * 会话管理逻辑委托给 ChatSessionController，
 * 消息收发逻辑委托给 ChatController，
 * 键盘监听委托给 KeyboardController。
 */
@ComponentV2
export struct ChatTabComp {
  /** 聊天页面视图状态（消息列表、输入内容、loading、sessionId）*/
  @Local vm: ChatViewModel = new ChatViewModel()

  /** 软键盘当前高度（vp），用于动态 padding 避免遮挡输入框 */
  @Local keyboardHeight: number = 0

  /** 全局主题（亮色/暗黑）*/
  @Local theme: ThemeState = getThemeState()

  /** 右侧历史会话抽屉是否打开 */
  @Local historyDrawerVisible: boolean = false

  /** 会话加载或持久化是否仍在进行，用于串行化会话级操作 */
  @Local sessionOperationPending: boolean = false

  /** 消息收发控制器 */
  @Local controller: ChatController = new ChatController(this.vm)

  /** 会话管理控制器（加载、新建、持久化） */
  private sessionController: ChatSessionController = new ChatSessionController(this.vm)

  /** 键盘监听控制器（注册/注销 keyboardHeightChange 事件）*/
  private keyboardController: KeyboardController = new KeyboardController()

  // ─── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    // 初始化会话 ID（若为空则生成新 ID）
    this.sessionController.initSession()

    // 禁用系统默认的键盘顶起模式，改用手动 padding 控制
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (error) {
      LogUtil.e('ChatTabComp', 'set keyboard avoid mode failed: ' + JSON.stringify(error))
    }

    // 启动键盘监听；收到高度变化时执行动画更新 padding
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.keyboardController.init(ctx, (heightVp: number, isShowing: boolean) => {
      this.getUIContext().animateTo(
        { duration: isShowing ? 300 : 250, curve: Curve.EaseOut },
        () => {
          this.keyboardHeight = heightVp
        }
      )
    })
  }

  aboutToDisappear(): void {
    // 恢复系统默认键盘模式，释放键盘监听资源
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (error) {
      LogUtil.e('ChatTabComp', 'restore keyboard avoid mode failed: ' + JSON.stringify(error))
    }

    this.keyboardController.dispose()
  }

  /**
   * 监听 loading 状态：
   * 流式生成结束（isLoading 从 true 变为 false）时自动持久化当前会话。
   */
  @Monitor('vm.isLoading')
  onLoadingChange(): void {
    if (this.vm.isLoading) {
      return
    }
    // 流式结束，将会话写入 RDB
    this.persistCurrentSession()
  }

  private async persistCurrentSession(): Promise<void> {
    this.sessionOperationPending = true
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      await this.sessionController.persistSession(ctx)
    } finally {
      this.sessionOperationPending = false
    }
  }

  private showGeneratingHint(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: 'AI 正在生成回复，请先停止或等待完成',
        duration: 1800
      })
    } catch (error) {
      LogUtil.e('ChatTabComp', 'show generating hint failed: ' + JSON.stringify(error))
    }
  }

  private openHistoryDrawer(): void {
    if (this.sessionOperationPending) {
      this.showOperationPendingHint()
      return
    }
    try {
      this.getUIContext().getFocusController().clearFocus()
    } catch (error) {
      LogUtil.e('ChatTabComp', 'clear input focus failed: ' + JSON.stringify(error))
    }

    this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.historyDrawerVisible = true
    })
  }

  private closeHistoryDrawer(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.historyDrawerVisible = false
    })
  }

  private requestNewSession(): void {
    if (this.sessionOperationPending) {
      this.showOperationPendingHint()
      return
    }
    if (!this.sessionController.newSession()) {
      this.showGeneratingHint()
      return
    }
    this.closeHistoryDrawer()
  }

  private async selectHistorySession(sessionId: string): Promise<void> {
    if (this.vm.isLoading) {
      this.showGeneratingHint()
      return
    }
    if (this.sessionOperationPending) {
      this.showOperationPendingHint()
      return
    }

    this.sessionOperationPending = true
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const loaded = await this.sessionController.loadSessionById(sessionId, ctx)
      if (!loaded) {
        try {
          this.getUIContext().getPromptAction().showToast({
            message: '该会话已不存在，请刷新后重试',
            duration: 1600
          })
        } catch (error) {
          LogUtil.e('ChatTabComp', 'show load failure hint failed: ' + JSON.stringify(error))
        }
        return
      }
      this.closeHistoryDrawer()
    } finally {
      this.sessionOperationPending = false
    }
  }

  private showOperationPendingHint(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: '正在保存或加载会话，请稍候',
        duration: 1500
      })
    } catch (error) {
      LogUtil.e('ChatTabComp', 'show operation hint failed: ' + JSON.stringify(error))
    }
  }

  private onHistorySessionDeleted(sessionId: string): void {
    if (sessionId === this.vm.sessionId) {
      this.sessionController.newSession()
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          Text('AI 助手')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)

          Blank()

          Text('+ 新会话')
            .fontSize(14)
            .fontColor(this.vm.isLoading ? this.theme.textTertiary : this.theme.primary)
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .onClick(() => {
              this.requestNewSession()
            })

          Text('历史会话')
            .fontSize(14)
            .fontColor(this.theme.textPrimary)
            .padding({ left: 10, right: 4, top: 8, bottom: 8 })
            .onClick(() => {
              this.openHistoryDrawer()
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 20, right: 12 })
        .backgroundColor(this.theme.surface)
        .border({ width: { bottom: 0.5 }, color: this.theme.divider })

        ChatListComp({ vm: this.vm, controller: this.controller })
          .layoutWeight(1)

        ChatInputComp({
          inputContent: this.vm.inputContent,
          isGenerating: this.vm.isLoading,
          onInputChange: (val: string) => {
            this.vm.inputContent = val
          },
          onSend: () => {
            this.controller.sendMessage()
          },
          onStop: () => {
            this.controller.stopGeneration()
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme.bg)
      .padding({
        bottom: this.keyboardHeight > 0
          ? Math.max(0, this.keyboardHeight - 56 - WindowUtil.getBottomAvoidHeight())
          : 0
      })
      .expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])

      if (this.historyDrawerVisible) {
        ChatHistoryDrawerComp({
          visible: true,
          isGenerating: this.vm.isLoading,
          operationPending: this.sessionOperationPending,
          currentSessionId: this.vm.sessionId,
          onClose: () => {
            this.closeHistoryDrawer()
          },
          onSelectSession: (sessionId: string) => {
            return this.selectHistorySession(sessionId)
          },
          onNewSession: () => {
            this.requestNewSession()
          },
          onSessionDeleted: (sessionId: string) => {
            this.onHistorySessionDeleted(sessionId)
          },
          onOperationStateChange: (pending: boolean) => {
            this.sessionOperationPending = pending
          }
        })
          .zIndex(10)
          .transition(
            TransitionEffect.move(TransitionEdge.END)
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 240, curve: Curve.EaseOut })
          )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
