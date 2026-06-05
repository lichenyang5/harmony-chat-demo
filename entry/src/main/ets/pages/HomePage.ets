import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { AppStorageV2 } from '@kit.ArkUI'
import { AppTabState } from '../viewmodel/AppTabState'
import { HomeTabComp } from '../components/HomeTabComp'
import { ChatTabComp, ChatLoadState, getChatLoadState } from 'chat'
import { ProfileTabComp } from '../components/ProfileTabComp'
import { WindowUtil } from 'common'
import { AuthPersist, getAuthPersist } from '../utils/AuthPersist'
import { ThemeState, getThemeState } from '../viewmodel/ThemeState'

/**
 * 应用首页（三 Tab 容器）。
 *
 * 职责：
 * - 作为三个功能 Tab 的容器（首页、AI助手、我的）
 * - 通过 @Provider 向子 Tab 组件注入登录状态和主题状态
 * - 监听跨页面会话加载信号，自动切换到 Chat Tab
 *
 * 信号流（跨页会话加载）：
 * ChatHistoryPage 设置 pendingSessionId
 * → HomePage @Monitor 切换 Tab 到 index=1
 * → ChatTabComp @Monitor 调用 loadSessionById 恢复会话
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_HOME })
@ComponentV2
export struct HomePage {
  /** Tab 下标，通过 AppStorageV2 在全局共享（ProfileTabComp 也会读取）*/
  @Local tabState: AppTabState = AppStorageV2.connect(AppTabState, 'AppTabState', () => new AppTabState())!
  /** 底部安全区高度（手势条/虚拟导航条），用于 TabBar padding */
  @Local bottomAvoid: number = WindowUtil.getBottomAvoidHeight()

  /** Provider 1：登录凭证，供 HomeTabComp / ProfileTabComp 通过 @Consumer 消费 */
  @Provider() auth: AuthPersist = getAuthPersist()
  /** Provider 2：全局主题，供所有 Tab 组件通过 @Consumer 消费 */
  @Provider() theme: ThemeState = getThemeState()

  /**
   * 跨页面加载信号：
   * ChatHistoryPage 点击某条会话后设置 pendingSessionId 并 pop，
   * 此处监听到变化后切到 Chat Tab（index = 1），
   * ChatTabComp 内再监听并执行 loadSessionById。
   */
  @Local chatLoadState: ChatLoadState = getChatLoadState()

  /**
   * 监听跨页面会话信号，有信号时切换到 Chat Tab。
   * ChatTabComp 负责实际的会话加载。
   */
  @Monitor('chatLoadState.pendingSessionId')
  onPendingSession(): void {
    if (this.chatLoadState.pendingSessionId) {
      this.tabState.currentIndex = 1
    }
  }

  aboutToAppear(): void {
    console.log('ooo这是混淆测试')
  }

  /**
   * TabBar 单个 item 的 @Builder 模板。
   * 选中/未选中通过 tabActive / tabInactive 颜色区分。
   *
   * @param index  该 Tab 的下标
   * @param label  显示文字
   * @param icon   显示图标（emoji）
   */
  @Builder
  tabBarItem(index: number, label: string, icon: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(22)
        .fontColor(this.tabState.currentIndex === index ? this.theme.tabActive : this.theme.tabInactive)

      Text(label)
        .fontSize(10)
        .fontColor(this.tabState.currentIndex === index ? this.theme.tabActive : this.theme.tabInactive)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomAvoid })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme.surface)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.tabState.currentIndex }) {
      TabContent() {
        HomeTabComp()
      }
      .tabBar(this.tabBarItem(0, '首页', '⌂'))

      TabContent() {
        ChatTabComp()
      }
      .tabBar(this.tabBarItem(1, 'AI助手', '✦'))

      TabContent() {
        ProfileTabComp()
      }
      .tabBar(this.tabBarItem(2, '我的', '○'))
    }
    .width('100%')
    .height('100%')
    .barHeight(56 + this.bottomAvoid)
    .divider({ strokeWidth: 0.5, color: this.theme.divider })
    .onChange((index: number) => {
      // 同步更新 AppStorageV2 中的 Tab 下标
      this.tabState.currentIndex = index
    })
  }
}