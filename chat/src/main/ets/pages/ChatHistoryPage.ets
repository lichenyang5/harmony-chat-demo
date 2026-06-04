import { ChatRoutes } from '../constants/ChatRoutes'
import { HMRouter, HMRouterMgr, HMLifecycleState } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'
import { ChatSession } from '../models/chatModel'
import { loadSessions, deleteSession } from '../utils/ChatPersist'
import { NAV_ID, HMUtil, ThemeState, getThemeState } from 'common'

@HMRouter({
  pageUrl: ChatRoutes.PAGE_CHAT_HISTORY,
  interceptors: ['AuthInterceptor'] // ← 通过 interceptorName 字符串引用
})
@ComponentV2
export struct ChatHistoryPage {
  @Local sessions: ChatSession[] = []
  @Local theme: ThemeState = getThemeState()

  private ctx: common.UIAbilityContext | null = null

  aboutToAppear(): void {
    this.ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.loadData()

    // 注册 onShown：每次页面被显示（包括从 ChatPage pop 回来）触发
    HMRouterMgr.getCurrentLifecycleOwner()?.addObserver(
      HMLifecycleState.onShown,
      () => {
        console.log('[ChatHistoryPage] onShown 触发，刷新列表')
        this.loadData()
      }
    )
  }

  aboutToDisappear(): void {
    HMRouterMgr.getCurrentLifecycleOwner()?.removeObserver(HMLifecycleState.onShown)
  }

  private loadData(): void {
    if (!this.ctx) {
      return
    }

    this.sessions = loadSessions(this.ctx)
  }

  private onDelete(sessionId: string): void {
    if (!this.ctx) {
      return
    }

    deleteSession(this.ctx, sessionId)

    // 直接从本地列表移除，不需要重新读文件
    this.sessions = this.sessions.filter(s => s.id !== sessionId)
  }

  private formatTime(ms: number): string {
    const d = new Date(ms)
    const now = new Date()
    const isToday = d.toDateString() === now.toDateString()

    if (isToday) {
      // 今天：只显示时分
      return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
    }

    // 其他：显示月/日
    return `${d.getMonth() + 1}/${d.getDate()}`
  }

  build() {
    Column() {
      // 顶部导航栏
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
        // 空状态
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
        // 历史会话列表
        List() {
          ForEach(this.sessions, (session: ChatSession) => {
            ListItem() {
              Row({ space: 12 }) {
                // 头像（取标题第一个字）
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

                    Text(this.formatTime(session.updateTime))
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
            // swipeAction：左滑显示删除按钮（鸿蒙 ListItem 内置手势）
            .swipeAction({ end: this.deleteButton(session.id) })
            .onClick(() => {
              // 点击进入历史会话（只读模式，后续可扩展继续对话）
              HMRouterMgr.push({
                navigationId: NAV_ID,
                pageUrl: ChatRoutes.PAGE_CHAT,
                param: session
              })
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

  // 左滑删除按钮（@Builder 必须用箭头函数，避免 this 丢失）
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