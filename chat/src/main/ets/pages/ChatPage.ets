import { ChatRoutes } from '../constants/ChatRoutes'
import { HMRouter, HMRouterMgr, HMParamType } from '@hadss/hmrouter'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { HMUtil, ThemeState, getThemeState } from 'common'
import { ChatController } from '../controller/ChatController'
import { ChatSessionController } from '../controller/ChatSessionController'
import { KeyboardController } from '../controller/KeyboardController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from '../components/ChatListComp'
import { ChatInputComp } from '../components/ChatInputComp'
import { ChatSession } from '../models/chatModel'

/**
 * 聊天独立页面（可从 ChatHistoryPage push 进来查看历史会话）。
 *
 * 职责：纯 UI 渲染（消息列表、输入框、顶部栏、历史记录抽屉）。
 * 会话恢复委托给 ChatSessionController，
 * 消息收发委托给 ChatController，
 * 键盘监听委托给 KeyboardController。
 */
@HMRouter({ pageUrl: ChatRoutes.PAGE_CHAT })
@ComponentV2
export struct ChatPage {
  /** 聊天页面视图状态（消息列表、输入内容、loading、sessionId）*/
  @Local vm: ChatViewModel = new ChatViewModel()

  /** 历史记录抽屉是否显示 */
  @Local showDrawer: boolean = false

  /** 软键盘当前高度（vp），用于动态 padding 避免遮挡输入框 */
  @Local keyboardHeight: number = 0

  /** 全局主题（亮色/暗黑）*/
  @Local theme: ThemeState = getThemeState()

  @Local controller: ChatController = new ChatController(this.vm)

  /** 会话管理控制器（恢复、初始化 session ID）*/
  private sessionController: ChatSessionController = new ChatSessionController(this.vm)

  /** 键盘监听控制器（注册/注销 keyboardHeightChange 事件）*/
  private keyboardController: KeyboardController = new KeyboardController()

  // ─── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    // 尝试从路由参数读取历史会话（由 ChatHistoryPage push 时携带）
    const session = HMRouterMgr.getCurrentParam(HMParamType.routeParam) as ChatSession | null

    if (session && session.messages && session.messages.length > 0) {
      // 恢复历史会话：将 ChatMessagePlain 列表转换为 ChatMessage（@ObservedV2）
      this.sessionController.restoreSession(session)
    } else {
      // 无历史参数：新会话，生成时间戳 sessionId
      this.sessionController.initSession()
    }

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
  }

  aboutToDisappear(): void {
    // 恢复系统默认键盘模式，释放键盘监听资源
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (_) {
    }

    this.keyboardController.dispose()
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        // ── 顶部导航栏 ────────────────────────────────────────────────
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

          // 汉堡菜单按钮，控制历史记录抽屉的显隐
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

        // ── 消息列表 ──────────────────────────────────────────────────
        ChatListComp({ vm: this.vm })
          .layoutWeight(1)

        // ── 输入框组件 ────────────────────────────────────────────────
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

      // ── 历史记录侧边抽屉（从右侧划入）──────────────────────────────
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
