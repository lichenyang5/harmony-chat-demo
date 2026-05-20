import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { PageShell } from '../components/PageShell'
import { ProductManager } from '../components/product/ProductManager'
import { RouteConstants } from '../constants/RouteConstants'
import { globalTabState } from '../stores/TabState'
interface PageParam {
  title?: string
  from?: string
}

@HMRouter({ pageUrl: RouteConstants.HOME })
@ComponentV2
export struct HomeBuilder {

  @Local title: string = 'Home'
  @Local from: string = '默认入口'

  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.HOME)
    const param = HMRouterMgr.getCurrentParam() as PageParam
    this.title = param?.title ?? 'Home'
    this.from = param?.from ?? '默认入口'
  }

  @Builder
  BackButtonBuilder() {
    Text('‹')
      .fontSize(32)
      .width(40)
      .height(40)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        HMRouterMgr.pop()
      })
  }

  @Builder
  ContentBuilder() {
    ProductManager({
      from: this.from
    })
  }

  build() {
    PageShell({
      title: this.title,
      from: this.from,
      leftBuilder: this.BackButtonBuilder,
      contentBuilder: this.ContentBuilder
    })
  }
}