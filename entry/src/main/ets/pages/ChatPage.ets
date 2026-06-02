import { HMRouter } from '@hadss/hmrouter'
import { HMUtil } from '../utils/HMUtil'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from '../components/ChatListComp'
import { ChatInputComp } from '../components/ChatInputComp'
import { window, display, KeyboardAvoidMode } from '@kit.ArkUI'
import { route } from '../constants/HMConstants'

@HMRouter({ pageUrl: route.PAGE_CHAT })
@ComponentV2
export struct ChatPage {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)
  @Local showDrawer: boolean = false
  @Local keyboardHeight: number = 0
  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {}
    this.initKeyboardListener()
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
          { duration: heightPx > 0 ? 300 : 250, curve: Curve.EaseOut },
          () => { this.keyboardHeight = heightVp }
        )
      })
    } catch (e) {
      console.error('[ChatPage] keyboard listener failed', JSON.stringify(e))
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {

      Column() {
        // 顶部栏
        Row() {
          Text('←')
            .fontSize(22)
            .padding(8)
            .onClick(() => { HMUtil.pop() })

          Blank()

          Text('AI 助手').fontSize(18).fontWeight(FontWeight.Medium)

          Blank()

          Text('☰')
            .fontSize(22)
            .padding(8)
            .onClick(() => { this.showDrawer = !this.showDrawer })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 8 })

        // ✅ layoutWeight(1)：撑满剩余高度，键盘弹起时自动收缩
        ChatListComp({ vm: this.vm })
          .layoutWeight(1)

        ChatInputComp({
          inputContent: this.vm.inputContent,
          onInputChange: (val: string) => { this.vm.inputContent = val },
          onSend: () => { this.controller.sendMessage() }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
      // ✅ 键盘避让：Column 底部 padding = 键盘高度，内容整体上移
      .padding({ bottom: this.keyboardHeight })

      // 历史记录抽屉
      if (this.showDrawer) {
        Column() {
          Row() {
            Text('历史记录').fontSize(18).fontWeight(FontWeight.Medium)
            Blank()
            Text('✕')
              .fontSize(18)
              .onClick(() => { this.showDrawer = false })
          }
          .width('100%')
          .padding(16)

          Text('暂无历史记录').fontColor('#999999').padding(16)
        }
        .width('70%')
        .height('100%')
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 8, color: '#33000000', offsetX: -4 })
      }

    }
    .width('100%')
    .height('100%')
  }
}
