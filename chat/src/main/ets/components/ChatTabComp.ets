import { window, display, KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from './ChatListComp'
import { ChatInputComp } from './ChatInputComp'
import { WindowUtil, ThemeState, getThemeState } from 'common'
import { saveSession } from '../utils/ChatPersist'
import { ChatSession } from '../models/chatModel'

@ComponentV2
export struct ChatTabComp {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)
  @Local keyboardHeight: number = 0
  @Local theme: ThemeState = getThemeState()

  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    // 每次进入 Tab 生成新会话 ID
    this.vm.sessionId = Date.now().toString()

    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {}

    this.initKeyboardListener()
  }

  // 流结束时（isLoading 从 true → false）持久化当前会话
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

  private persistSession(): void {
    if (this.vm.historyMessage.length === 0) {
      return
    }

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!ctx) {
      return
    }

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
      }
      .width('100%')
      .height(56)
      .padding({ left: 20 })
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      ChatListComp({ vm: this.vm })
        .layoutWeight(1)

      ChatInputComp({
        inputContent: this.vm.inputContent,
        onInputChange: (val: string) => {
          this.vm.inputContent = val
        },
        onSend: () => {
          this.controller.sendMessage()
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