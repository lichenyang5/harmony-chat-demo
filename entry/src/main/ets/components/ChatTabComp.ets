import { window, display } from '@kit.ArkUI'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from './ChatListComp'
import { ChatInputComp } from './ChatInputComp'

@ComponentV2
export struct ChatTabComp {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)
  @Local keyboardHeight: number = 0
  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    this.initKeyboardListener()
  }

  aboutToDisappear(): void {
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
      console.error('[ChatTabComp] keyboard listener failed', JSON.stringify(e))
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('AI 助手').fontSize(18).fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(56)
      .padding({ left: 20 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#EBEBEB' })

      // ✅ .layoutWeight(1)：让 ChatListComp 在 Column 里撑满剩余高度
      //    不加的话 ChatListComp 高度为 0，输入框会跑到顶部
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
    .backgroundColor(Color.White)
    // ✅ 键盘避让加在 Column 上：
    //    padding.bottom = keyboardHeight → Column 内容区上移
    //    layoutWeight(1) 的 ChatListComp 自动收缩让出空间
    //    ChatInputComp 紧贴键盘顶部
    .padding({ bottom: this.keyboardHeight })
  }
}
