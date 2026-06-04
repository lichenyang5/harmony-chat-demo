import { window, display, KeyboardAvoidMode } from '@kit.ArkUI'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from './ChatListComp'
import { ChatInputComp } from './ChatInputComp'
import { WindowUtil } from 'common'
import { saveSession } from '../utils/ChatPersist'
import { ChatSession } from '../models/chatModel'
import { common } from '@kit.AbilityKit'

@ComponentV2
export struct ChatTabComp {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)
  @Local keyboardHeight: number = 0
  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    // 每次进入 Tab 生成新会话 ID（时间戳，天然唯一）
    this.vm.sessionId = Date.now().toString()

    /**
     * ⚠️ 关键：禁用系统默认键盘避让
     *
     * 默认 KeyboardAvoidMode.OFFSET：键盘弹起时系统自动把 Window 内容上移
     * 如果同时手动加 Column.padding.bottom = keyboardHeight → 双重补偿 → 输入框飞到顶部
     *
     * 改为 NONE：系统不动，只由 Column.padding.bottom 手动控制，输入框精准贴键盘
     * 参考：公司 AgentChatComp.aboutToAppear() 第 93 行
     */
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {}

    this.initKeyboardListener()
  }

  // 打字机动画结束时 pendingResponse 变回 ''，此时 AI 消息已推入 historyMessage
  // Tabs 切换不触发 aboutToDisappear，所以在这里保存而不是在销毁时
  @Monitor('vm.pendingResponse')
  onResponseConsumed(): void {
    if (this.vm.pendingResponse === '' && this.vm.historyMessage.length > 0) {
      this.persistSession()
    }
  }

  aboutToDisappear(): void {
    // 恢复默认，避免影响其他页面（如 LoginPage 的表单）
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (_) {}
    try {
      this.mainWindow?.off('keyboardHeightChange')
    } catch (_) {}
    this.mainWindow = null
  }

  private persistSession(): void {
    if (this.vm.historyMessage.length === 0) return

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!ctx) return

    const messages = this.vm.historyMessage
    // 标题：第一条用户消息前 20 字，没有就用「新对话」
    const firstUser = messages.find(m => m.role === 'user')
    const title = firstUser
      ? firstUser.content.substring(0, 20) + (firstUser.content.length > 20 ? '...' : '')
      : '新对话'
    // 预览：最后一条消息前 30 字
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
      Row() {
        Text('AI 助手').fontSize(18).fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(56)
      .padding({ left: 20 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#EBEBEB' })

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
    /**
     * keyboardHeight 是从屏幕最底部算起的键盘高度（包含 Tab Bar 区域）
     * 但 ChatTabComp 的 Column 只占 TabContent 高度（不含 Tab Bar）
     *
     * 错误：padding.bottom = keyboardHeight        → 多减了 tabBarHeight，留出空隙
     * 正确：padding.bottom = keyboardHeight - tabBarHeight  → 精准对齐键盘顶部
     *
     * tabBarHeight = 固定内容区 56 + 手势条 bottomAvoid
     */
    .padding({ bottom: this.keyboardHeight > 0
      ? Math.max(0, this.keyboardHeight - 56 - WindowUtil.getBottomAvoidHeight())
      : 0
    })
    .expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])
  }
}
