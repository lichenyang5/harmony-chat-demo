import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { PageShell } from '../components/PageShell'

interface ProductDetailParam {
  id?: number
  title?: string
  from?: string
}

@HMRouter({ pageUrl: 'pages/ProductDetail' })
@ComponentV2
export struct ProductDetail {
  @Local title: string = '商品详情'
  @Local from: string = '默认入口'
  @Local productId: number = 0

  aboutToAppear(): void {
    const param = HMRouterMgr.getCurrentParam() as ProductDetailParam

    console.log('详情页接收到参数：' + JSON.stringify(param))

    this.productId = Number(param?.id ?? 0)
    this.title = param?.title ?? '商品详情'
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
    Column({ space: 16 }) {
      Text('商品详情页')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)

      Text(`商品ID：${this.productId}`)
        .fontSize(18)

      Text(`商品名称：${this.title}`)
        .fontSize(18)

      Text(`来源：${this.from}`)
        .fontSize(18)

      Button('返回')
        .onClick(() => {
          HMRouterMgr.pop()
        })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
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