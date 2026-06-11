import { HMNavigation } from '@hadss/hmrouter'
import { NetMonitorOverlay } from 'common'

@Entry
@ComponentV2
export struct Index {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HMNavigation({
        navigationId: 'MainNavigation',
        homePageUrl: 'pages/Home',   // ← Login 改成 Home
        options: {}
      })

      // 网络调试悬浮球 + 面板：盖在所有页面之上，release 包不渲染
      NetMonitorOverlay()
    }
    .width('100%')
    .height('100%')
  }
}
