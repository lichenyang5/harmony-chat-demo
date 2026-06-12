import { KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ChatController } from '../controller/ChatController'
import { ChatSessionController } from '../controller/ChatSessionController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from './ChatListComp'
import { ChatInputComp } from './ChatInputComp'
import { WindowUtil, ThemeState, getThemeState, KeyboardController } from 'common'
import { ChatLoadState, getChatLoadState } from '../viewmodel/ChatLoadState'

/**
 * 聊天 Tab 组件（嵌入 HomePage 的 Tab 容器中）。
 *
 * 职责：纯 UI 渲染（消息列表、输入框、顶部栏）和状态监听。
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

  /**
   * 跨页面加载信号：
   * ChatHistoryPage 点击某条会话时设置 pendingSessionId，
   * 本组件通过 @Monitor 监听并加载对应会话。
   */
  @Local chatLoadState: ChatLoadState = getChatLoadState()

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
    } catch (_) {
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

    // 若 App 刚启动时已有待加载会话（冷启动场景），立即加载
    if (this.chatLoadState.pendingSessionId) {
      this.sessionController.loadSessionById(this.chatLoadState.pendingSessionId, ctx)
      this.chatLoadState.pendingSessionId = ''
    }
  }

  aboutToDisappear(): void {
    // 恢复系统默认键盘模式，释放键盘监听资源
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (_) {
    }

    this.keyboardController.dispose()
  }

  // ─── @Monitor 监听 ─────────────────────────────────────────────────────────

  /**
   * 监听跨页面信号：
   * 从 ChatHistoryPage 点某条历史会话回到 HomePage 时，
   * pendingSessionId 被设置，此处响应并加载对应会话。
   */
  @Monitor('chatLoadState.pendingSessionId')
  onPendingSessionChange(): void {
    const id = this.chatLoadState.pendingSessionId
    if (id) {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      this.sessionController.loadSessionById(id, ctx)
      this.chatLoadState.pendingSessionId = ''
    }
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
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.sessionController.persistSession(ctx)
  }

  /**
   * 监听"会话被删除"信号：
   * ChatHistoryPage 左滑删除后，若被删的就是当前正在显示的会话，
   * 直接重置 UI 成新会话，避免用户看到一份"鬼数据"。
   * 消费完信号必须清零，否则下次删同一 id 时 @Trace 值没变不会再触发。
   */
  @Monitor('chatLoadState.deletedSessionId')
  onDeletedSessionChange(): void {
    const deletedId = this.chatLoadState.deletedSessionId
    if (!deletedId) {
      return
    }
    if (this.vm.sessionId === deletedId) {
      // 直接调 vm.resetForNewSession 而不是 controller.newSession，
      // 后者会因 isLoading 拒绝重置；既然会话已删，不再保护流式
      this.vm.resetForNewSession()
    }
    this.chatLoadState.deletedSessionId = ''
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Column() {
      // ── 顶部栏：标题 + 新建会话按钮 ──────────────────────────────────
      Row() {
        Text('AI 助手')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()

        Text('+ 新会话')
          .fontSize(14)
          // 生成中时置灰，防止打断流式请求
          .fontColor(this.vm.isLoading ? this.theme.textTertiary : this.theme.primary)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.sessionController.newSession()
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 16 })
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      // ── 消息列表 ────────────────────────────────────────────────────
      ChatListComp({ vm: this.vm, controller: this.controller })
        .layoutWeight(1)

      // ── 输入框组件（发送/停止回调直接调用 controller）──────────────
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
    // 键盘弹出时，通过 padding 上移输入框，避免被遮挡
    .padding({
      bottom: this.keyboardHeight > 0
        ? Math.max(0, this.keyboardHeight - 56 - WindowUtil.getBottomAvoidHeight())
        : 0
    })
    .expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])
  }
}
