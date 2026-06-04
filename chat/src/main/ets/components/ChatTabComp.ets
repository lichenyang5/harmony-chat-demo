import { window, display, KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from './ChatListComp'
import { ChatInputComp } from './ChatInputComp'
import { WindowUtil, ThemeState, getThemeState } from 'common'
import { saveSession, loadSessions } from '../utils/ChatPersist'
import { ChatSession, ChatMessage } from '../models/chatModel'
import { ChatLoadState, getChatLoadState } from '../viewmodel/ChatLoadState'

@ComponentV2
export struct ChatTabComp {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)
  @Local keyboardHeight: number = 0
  @Local theme: ThemeState = getThemeState()

  // 跨页面信号：ChatHistory 点击会话时设置 pendingSessionId
  @Local chatLoadState: ChatLoadState = getChatLoadState()

  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    // 默认新会话；若 chatLoadState 已经有 pendingSessionId 会在 @Monitor 里覆盖
    this.vm.sessionId = Date.now().toString()

    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {}

    this.initKeyboardListener()

    // App 启动时如果 pendingSessionId 已存在，主动加载一次（兜底）
    if (this.chatLoadState.pendingSessionId) {
      this.loadSession(this.chatLoadState.pendingSessionId)
      this.chatLoadState.pendingSessionId = ''
    }
  }

  // 监听跨页面信号：从 ChatHistory 切过来时加载对应会话
  @Monitor('chatLoadState.pendingSessionId')
  onPendingSessionChange(): void {
    const id = this.chatLoadState.pendingSessionId
    if (id) {
      this.loadSession(id)
      this.chatLoadState.pendingSessionId = ''   // 消费完清空，避免重复触发
    }
  }

  // 流结束时持久化当前会话
  @Monitor('vm.isLoading')
  onLoadingChange(): void {
    if (!this.vm.isLoading && this.vm.historyMessage.length > 0) {
      this.persistSession()
    }
  }

  aboutToDisappear(): void {
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (_) {}

    try {
      this.mainWindow?.off('keyboardHeightChange')
    } catch (_) {}

    this.mainWindow = null
  }

  /**
   * 加载指定会话（继续聊天，非只读）
   *
   * 关键：从 PersistenceV2/JSON 反序列化出来的 messages 是 plain object，
   * 不是 @ObservedV2 的 ChatMessage 实例。必须 new 出新实例，
   * 否则后续 @Trace content 不会触发响应式更新，甚至运行时崩溃。
   */
  private loadSession(id: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!ctx) {
      console.error('[ChatTabComp] loadSession: ctx is null')
      return
    }

    const sessions = loadSessions(ctx)
    const target = sessions.find(s => s.id === id)
    if (!target) {
      console.warn('[ChatTabComp] session not found:', id)
      return
    }

    // 把 plain object 重建为 @ObservedV2 的 ChatMessage 实例
    const restored: ChatMessage[] = []
    for (let i = 0; i < target.messages.length; i++) {
      const plain = target.messages[i]
      const msg = new ChatMessage()
      msg.id = plain.id
      msg.role = plain.role
      msg.content = plain.content
      msg.createTime = plain.createTime
      msg.sessionId = plain.sessionId
      restored.push(msg)
    }

    this.vm.sessionId = target.id
    this.vm.historyMessage = restored
    this.vm.inputContent = ''
  }

  /**
   * 新建会话：清空当前历史，生成新 sessionId
   */
  private newSession(): void {
    if (this.vm.isLoading) return   // 流式中禁止新建
    this.vm.sessionId = Date.now().toString()
    this.vm.historyMessage = []
    this.vm.inputContent = ''
  }

  private persistSession(): void {
    if (this.vm.historyMessage.length === 0) return

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!ctx) return

    const messages = this.vm.historyMessage
    const firstUser = messages.find(m => m.role === 'user')

    const title = firstUser
      ? firstUser.content.substring(0, 20) + (firstUser.content.length > 20 ? '...' : '')
      : '新对话'

    const last = messages[messages.length - 1]
    const preview = last.content.substring(0, 30) + (last.content.length > 30 ? '...' : '')

    const session: ChatSession = {
      id: this.vm.sessionId,
      title,
      preview,
      createTime: messages[0].createTime,
      updateTime: last.createTime,
      messages
    }

    saveSession(ctx, session)
  }

  private async initKeyboardListener(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext()
      if (!ctx) return

      const win = await window.getLastWindow(ctx)
      this.mainWindow = win

      win.on('keyboardHeightChange', (heightPx: number) => {
        const heightVp = heightPx > 0
          ? heightPx / display.getDefaultDisplaySync().densityPixels
          : 0

        this.getUIContext().animateTo(
          {
            duration: heightPx > 0 ? 300 : 250,
            curve: Curve.EaseOut
          },
          () => {
            this.keyboardHeight = heightVp
          }
        )
      })
    } catch (e) {
      console.error('[ChatTabComp] keyboard listener failed', JSON.stringify(e))
    }
  }

  build() {
    Column() {
      // 顶部栏：标题 + 新会话按钮
      Row() {
        Text('AI 助手')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()

        // 新会话按钮
        Text('+ 新会话')
          .fontSize(14)
          .fontColor(this.vm.isLoading ? this.theme.textTertiary : this.theme.primary)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.newSession()
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 16 })
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      ChatListComp({ vm: this.vm })
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
  }
}
