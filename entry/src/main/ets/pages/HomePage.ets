import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { AppStorageV2 } from '@kit.ArkUI'
import { AppTabState } from '../viewmodel/AppTabState'
import { HomeTabComp } from '../components/HomeTabComp'
import { ChatTabComp } from 'chat'
import { ProfileTabComp } from '../components/ProfileTabComp'
import { WindowUtil } from 'common'
import { AuthPersist, getAuthPersist } from '../utils/AuthPersist'
import { ThemeState, getThemeState } from '../viewmodel/ThemeState'

@HMRouter({ pageUrl: EntryRoutes.PAGE_HOME })
@ComponentV2
export struct HomePage {
  @Local tabState: AppTabState = AppStorageV2.connect(AppTabState, 'AppTabState', () => new AppTabState())!
  @Local bottomAvoid: number = WindowUtil.getBottomAvoidHeight()

  // Provider 1：登录状态，供所有 Tab 消费
  @Provider() auth: AuthPersist = getAuthPersist()

  // Provider 2：主题状态，供所有 Tab 消费
  @Provider() theme: ThemeState = getThemeState()

  aboutToAppear(): void {
    console.log('ooo这是混淆测试')
  }

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
      this.tabState.currentIndex = index
    })
  }
}