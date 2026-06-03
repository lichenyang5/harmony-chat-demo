import { HMRouter } from '@hadss/hmrouter'
import { AppStorageV2 } from '@kit.ArkUI'
import { AppTabState } from '../viewmodel/AppTabState'
import { HomeTabComp } from '../components/HomeTabComp'
import { ChatTabComp } from '../components/ChatTabComp'
import { ProfileTabComp } from '../components/ProfileTabComp'
import { route } from '../constants/HMConstants'
import { WindowUtil } from '../utils/WindowUtil'
import { AuthPersist, getAuthPersist } from '../utils/AuthPersist'
@HMRouter({ pageUrl: route.PAGE_HOME })
@ComponentV2
export struct HomePage {
  @Local tabState: AppTabState =
    AppStorageV2.connect(AppTabState, 'AppTabState', () => new AppTabState())!

  /**
   * 底部安全区高度（vp）
   * 手势条 / 虚拟导航键的高度，TabBar 需要额外占位防止被遮挡
   * 由 WindowUtil.init() 在 EntryAbility 里写入 AppStorage
   */
  @Local bottomAvoid: number = WindowUtil.getBottomAvoidHeight()
  /*
   * provider 爷孙组件 provider注册,子组件consumer获取
   * */
  @Provider() auth: AuthPersist = getAuthPersist()   // ← 新增
  @Builder
  tabBarItem(index: number, label: string, icon: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(22)
        .fontColor(this.tabState.currentIndex === index ? '#007DFF' : '#AAAAAA')
      Text(label)
        .fontSize(10)
        .fontColor(this.tabState.currentIndex === index ? '#007DFF' : '#AAAAAA')
    }
    .width('100%')
    .height('100%')
    // 把图标和文字往上推，让内容出现在手势条上方
    .padding({ bottom: this.bottomAvoid })
    .justifyContent(FlexAlign.Center)
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
    // barHeight = 固定内容区 56 + 底部手势条高度
    .barHeight(56 + this.bottomAvoid)
    .divider({ strokeWidth: 0.5, color: '#E8E8E8' })
    .onChange((index: number) => {
      this.tabState.currentIndex = index
    })
  }
}
