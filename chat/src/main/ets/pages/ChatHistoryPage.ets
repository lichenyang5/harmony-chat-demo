import { ChatRoutes } from '../constants/ChatRoutes'
import { HMRouter, HMRouterMgr, HMLifecycleState } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'
import { ChatSession } from '../models/chatModel'
import { HMUtil, ThemeState, getThemeState, LogUtil } from 'common'
import { ChatHistoryController } from '../controller/ChatHistoryController'

/**
 * 消息记录列表页。
 *
 * 职责：纯 UI 渲染（会话列表、空状态、左滑删除）。
 * 数据加载、删除、跳转、时间格式化委托给 ChatHistoryController。
 *
 * 受 AuthInterceptor 保护，未登录时会弹出登录提示。
 */
@HMRouter({
  pageUrl: ChatRoutes.PAGE_CHAT_HISTORY,
  interceptors: ['AuthInterceptor']
})
@ComponentV2
export struct ChatHistoryPage {
  /** 当前展示的会话列表，由 controller.loadData 填充 */
  @Local sessions: ChatSession[] = []
  /** 全局主题（亮色/暗黑），用于动态颜色 */
  @Local theme: ThemeState = getThemeState()

  /** UIAbility 上下文，用于 Preferences 读写，在 aboutToAppear 中初始化 */
  private ctx: common.UIAbilityContext | null = null

  private controller: ChatHistoryController = new ChatHistoryController()

  // ─── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    this.ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.loadData()

    // 注册 onShown：每次页面重新显示（包括从 ChatPage pop 回来）时刷新列表
    HMRouterMgr.getCurrentLifecycleOwner()?.addObserver(
      HMLifecycleState.onShown,
      () => {
        LogUtil.i('ChatHistoryPage', 'onShown 触发，刷新列表')
        this.loadData()
      }
    )
  }

  aboutToDisappear(): void {
    HMRouterMgr.getCurrentLifecycleOwner()?.removeObserver(HMLifecycleState.onShown)
  }

  // ─── 私有方法（薄封装，仅做参数准备，逻辑在 controller 中）──────────────────

  /** 从 RDB 加载会话列表并更新 UI（异步） */
  private async loadData(): Promise<void> {
    if (!this.ctx) {
      return
    }
    this.sessions = await this.controller.loadData(this.ctx)
  }

  /** 删除指定会话并更新本地列表（异步） */
  private async onDelete(sessionId: string): Promise<void> {
    if (!this.ctx) {
      return
    }
    this.sessions = await this.controller.deleteSession(this.ctx, sessionId, this.sessions)
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Column() {
      // ── 顶部导航栏 ──────────────────────────────────────────────────
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(this.theme.textPrimary)
          .padding(12)
          .onClick(() => {
            HMUtil.pop()
          })

        Text('消息记录')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      if (this.sessions.length === 0) {
        // ── 空状态 ────────────────────────────────────────────────────
        Column({ space: 12 }) {
          Text('')
            .fontSize(48)

          Text('暂无对话记录')
            .fontSize(15)
            .fontColor(this.theme.textTertiary)

          Text('去 AI 助手 Tab 开始聊天吧')
            .fontSize(13)
            .fontColor(this.theme.textPlaceholder)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.theme.bg)
      } else {
        // ── 历史会话列表（支持左滑删除）──────────────────────────────
        List() {
          ForEach(this.sessions, (session: ChatSession) => {
            ListItem() {
              Row({ space: 12 }) {
                // 头像：取会话标题第一个字
                Text(session.title.charAt(0))
                  .width(44)
                  .height(44)
                  .fontSize(18)
                  .fontColor(this.theme.onPrimary)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.theme.primary)
                  .borderRadius(22)
                  .flexShrink(0)

                Column({ space: 4 }) {
                  Row() {
                    Text(session.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme.textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)

                    // 格式化时间（今天显示 HH:mm，历史显示 M/D）
                    Text(this.controller.formatTime(session.updateTime))
                      .fontSize(12)
                      .fontColor(this.theme.textTertiary)
                  }
                  .width('100%')

                  Text(session.preview)
                    .fontSize(13)
                    .fontColor(this.theme.textSecondary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(this.theme.surface)
            }
            // 左滑显示删除按钮（ListItem 内置手势）
            .swipeAction({ end: this.deleteButton(session.id) })
            .onClick(() => {
              // 通过全局信号通知 ChatTabComp 加载该会话，然后 pop 回首页
              this.controller.openSession(session.id)
            })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({
          strokeWidth: 0.5,
          color: this.theme.divider,
          startMargin: 72
        })
        .backgroundColor(this.theme.bg)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }

  /**
   * 左滑删除按钮（@Builder 必须用箭头函数，避免 this 丢失问题）。
   */
  @Builder
  deleteButton(sessionId: string) {
    Button('删除')
      .width(72)
      .height('100%')
      .fontSize(14)
      .backgroundColor(this.theme.danger)
      .fontColor(this.theme.onDanger)
      .borderRadius(0)
      .onClick(() => {
        this.onDelete(sessionId)
      })
  }
}
