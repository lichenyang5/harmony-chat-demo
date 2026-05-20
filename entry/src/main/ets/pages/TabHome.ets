import { HMRouter } from '@hadss/hmrouter'
import { RouteConstants } from '../constants/RouteConstants'
import { globalTabState } from '../stores/TabState'

@HMRouter({ pageUrl: RouteConstants.TAB_HOME })
@ComponentV2
export struct TabHome {
  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.TAB_HOME)
  }

  build() {
    Column() {
      Text('首页')
        .fontSize(30)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}