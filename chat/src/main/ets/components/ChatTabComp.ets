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
    // 默认新会话；如果历史页已经设置了 pendingSessionId，下面会立刻加载历史会话覆盖
    if (!this.vm.sessionId) {
      this.vm.sessionId = Date.now().toString()
    }

    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {
    }

    this.initKeyboardListener()

    // App 启动或页面创建时，如果 pendingSessionId 已存在，主动加载一次兜底
    if (this.chatLoadState.pendingSessionId) {
      this.loadSession(this.chatLoadState.pendingSessionId)
      this.chatLoadState.pendingSessionId = ''
    }
  }

  /**
   * 监听跨页面信号：
   * 从 ChatHistoryPage 点某条历史会话回来时，加载对应会话。
   */
  @Monitor('chatLoadState.pendingSessionId')
  onPendingSessionChange(): void {
    const id = this.chatLoadState.pendingSessionId

    if (id) {
      this.loadSession(id)
      this.chatLoadState.pendingSessionId = ''
    }
  }

  /**
   * 流式结束时持久化当前会话。
   */
  @Monitor('vm.isLoading')
  onLoadingChange(): void {
    if (!this.vm.isLoading && this.vm.historyMessage.length > 0) {
      this.persistSession()
    }
  }

  aboutToDisappear(): void {
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (_) {
    }

    try {
      this.mainWindow?.off('keyboardHeightChange')
    } catch (_) {
    }

    this.mainWindow = null
  }

  /**
   * 加载指定历史会话。
   *
   * 重点：
   * 1. 从持久化里拿出来的数据可能是普通 plain object。
   * 2. 必须重新 new ChatMessage，否则 @Trace content 可能不稳定。
   * 3. 所有字段做兜底，避免 content / messages / id 为 undefined。
   */
  private loadSession(id: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext

    if (!ctx) {
      console.error('[ChatTabComp] loadSession: ctx is null')
      return
    }

    const sessions = loadSessions(ctx)
    const target = sessions.find((s: ChatSession) => s.id === id)

    if (!target) {
      console.warn('[ChatTabComp] session not found:', id)
      return
    }

    const restored: ChatMessage[] = []
    const sourceMessages: ChatMessage[] = target.messages ? target.messages : []

    for (let i = 0; i < sourceMessages.length; i++) {
      const plain = sourceMessages[i]

      const msg = new ChatMessage()
      msg.id = plain.id ? plain.id : `${id}_${i}`
      msg.role = plain.role ? plain.role : 'assistant'
      msg.content = plain.content ? plain.content : ''
      msg.createTime = plain.createTime ? plain.createTime : Date.now()
      msg.sessionId = plain.sessionId ? plain.sessionId : id

      restored.push(msg)
    }

    this.vm.sessionId = target.id ? target.id : id
    this.vm.historyMessage = restored

    // 加载历史会话后，必须清理输入框和 loading 状态
    this.vm.resetRuntimeState()
  }

  /**
   * 新建会话。
   */
  private newSession(): void {
    if (this.vm.isLoading) {
      return
    }

    this.vm.resetForNewSession()
  }

  /**
   * 持久化当前会话。
   *
   * 重点：
   * content 做空值防御，避免 substring / length 再次触发 undefined 报错。
   */
  private persistSession(): void {
    if (this.vm.historyMessage.length === 0) {
      return
    }

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext

    if (!ctx) {
      return
    }

    const messages = this.vm.historyMessage

    const firstUser = messages.find((m: ChatMessage) => m.role === 'user')
    const firstContent = firstUser && firstUser.content ? firstUser.content : ''

    const title = firstContent.length > 0
      ? firstContent.substring(0, 20) + (firstContent.length > 20 ? '...' : '')
      : '新对话'

    const last = messages[messages.length - 1]
    const lastContent = last && last.content ? last.content : ''

    const preview = lastContent.substring(0, 30) + (lastContent.length > 30 ? '...' : '')

    const first = messages[0]
    const createTime = first && first.createTime ? first.createTime : Date.now()
    const updateTime = last && last.createTime ? last.createTime : Date.now()

    const session: ChatSession = new ChatSession()
    session.id = this.vm.sessionId ? this.vm.sessionId : Date.now().toString()
    session.title = title
    session.preview = preview
    session.createTime = createTime
    session.updateTime = updateTime
    session.messages = messages

    saveSession(ctx, session)
  }

  private async initKeyboardListener(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext()

      if (!ctx) {
        return
      }

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
      Row() {
        Text('AI 助手')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()

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