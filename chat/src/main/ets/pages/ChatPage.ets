import { ChatRoutes } from '../constants/ChatRoutes'
import { HMRouter, HMRouterMgr, HMParamType } from '@hadss/hmrouter'
import { HMUtil, ThemeState, getThemeState } from 'common'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from '../components/ChatListComp'
import { ChatInputComp } from '../components/ChatInputComp'
import { window, display, KeyboardAvoidMode } from '@kit.ArkUI'
import { ChatSession, ChatMessage, ChatMessagePlain } from '../models/chatModel'

@HMRouter({ pageUrl: ChatRoutes.PAGE_CHAT })
@ComponentV2
export struct ChatPage {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)

  @Local showDrawer: boolean = false
  @Local keyboardHeight: number = 0
  @Local theme: ThemeState = getThemeState()

  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    const session = HMRouterMgr.getCurrentParam(HMParamType.routeParam) as ChatSession | null

    if (session && session.messages && session.messages.length > 0) {
      this.restoreSession(session)
    } else {
      if (!this.vm.sessionId) {
        this.vm.sessionId = Date.now().toString()
      }
    }

    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {
    }

    this.initKeyboardListener()
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

  private restoreSession(session: ChatSession): void {
    const restored: ChatMessage[] = []
    const sourceMessages: ChatMessagePlain[] = session.messages ? session.messages : []

    for (let i = 0; i < sourceMessages.length; i++) {
      const plain = sourceMessages[i]

      const msg = new ChatMessage()
      msg.id = plain.id ? plain.id : `${session.id}_${i}`
      msg.role = plain.role ? plain.role : 'assistant'
      msg.content = plain.content ? plain.content : ''
      msg.createTime = plain.createTime ? plain.createTime : Date.now()
      msg.sessionId = plain.sessionId ? plain.sessionId : session.id

      restored.push(msg)
    }

    this.vm.historyMessage = restored
    this.vm.sessionId = session.id ? session.id : Date.now().toString()
    this.vm.inputContent = ''
    this.vm.isLoading = false
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
      console.error('[ChatPage] keyboard listener failed', JSON.stringify(e))
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          Text('←')
            .fontSize(22)
            .fontColor(this.theme.textPrimary)
            .padding(8)
            .onClick(() => {
              HMUtil.pop()
            })

          Blank()

          Text('AI 助手')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)

          Blank()

          Text('☰')
            .fontSize(22)
            .fontColor(this.theme.textPrimary)
            .padding(8)
            .onClick(() => {
              this.showDrawer = !this.showDrawer
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 8 })
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
      .padding({ bottom: this.keyboardHeight })

      if (this.showDrawer) {
        Column() {
          Row() {
            Text('历史记录')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            Blank()

            Text('✕')
              .fontSize(18)
              .fontColor(this.theme.textPrimary)
              .onClick(() => {
                this.showDrawer = false
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.theme.surface)
          .border({ width: { bottom: 0.5 }, color: this.theme.divider })

          Text('暂无历史记录')
            .fontSize(14)
            .fontColor(this.theme.textSecondary)
            .padding(16)
        }
        .width('70%')
        .height('100%')
        .backgroundColor(this.theme.surface)
        .shadow({
          radius: 8,
          color: this.theme.drawerShadowColor,
          offsetX: -4
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}