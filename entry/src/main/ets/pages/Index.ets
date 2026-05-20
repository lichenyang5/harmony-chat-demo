import { HMNavigation, HMRouterMgr } from '@hadss/hmrouter'
import { RouteConstants, RouteFrom, TAB_ROUTES, TabRouteItem } from '../constants/RouteConstants'
import { TabState, globalTabState } from '../stores/TabState'

@Entry
@ComponentV2
struct Index {
  @Local tabState: TabState = globalTabState

  build() {
    Column() {
      HMNavigation({
        navigationId: RouteConstants.MAIN_NAVIGATION_ID,
        homePageUrl: RouteConstants.TAB_HOME
      })
        .layoutWeight(1)
        .width('100%')

      Row() {
        ForEach(TAB_ROUTES, (item: TabRouteItem) => {
          this.TabItem(item)
        }, (item: TabRouteItem) => item.pageUrl)
      }
      .width('100%')
      .height(60)
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabItem(item: TabRouteItem) {
    Column() {
      Text(item.title)
        .fontSize(14)
        .fontColor(this.tabState.currentTab === item.pageUrl ? '#007DFF' : '#666666')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (this.tabState.currentTab === item.pageUrl) {
        return
      }

      this.tabState.setCurrentTab(item.pageUrl)

      HMRouterMgr.push({
        pageUrl: item.pageUrl,
        param: {
          title: item.title,
          from: RouteFrom.TAB_BAR
        }
      })
    })
  }
}