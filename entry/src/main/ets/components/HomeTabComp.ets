import { HMRouterMgr, HMPopInfo } from '@hadss/hmrouter'
import { route, NAV_ID } from '../constants/HMConstants'
import { Product, MOCK_PRODUCTS } from '../models/productModel'

@ComponentV2
export struct HomeTabComp {
  // 购物车总数：由 ProductDetailPage pop 返回的 onResult 累加
  @Local cartCount: number = 0

  // 点击商品卡片 → push 传参 → 等待 onResult 拿回加购数量
  private goDetail(product: Product): void {
    HMRouterMgr.push(
      {
        navigationId: NAV_ID,
        pageUrl: route.PAGE_PRODUCT_DETAIL,
        param: product          // ← 路由传参：把整个 Product 对象传给详情页
      },
      {
        onResult: (popInfo: HMPopInfo) => {
          // ← pop 返回传参：详情页 setPopParam(n) 后 pop，result 就是 n
          const addCount = popInfo.result as number
          if (addCount > 0) {
            this.cartCount += addCount
          }
        }
      }
    )
  }

  @Builder
  productCard(product: Product) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 6 }) {
        // 占位图
        Row()
          .width('100%')
          .height(80)
          .backgroundColor('#EEF2FF')
          .borderRadius(8)

        Text(product.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(product.desc)
          .fontSize(11)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`¥${product.price}`)
          .fontSize(15)
          .fontColor('#FF4D4F')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding(10)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 4, color: '#0A000000', offsetY: 2 })

      // 角标（有 tag 时才显示）
      if (product.tag) {
        Text(product.tag)
          .fontSize(10)
          .fontColor(Color.White)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#007DFF')
          .borderRadius({ topRight: 12, bottomLeft: 8 })
      }
    }
    .onClick(() => { this.goDetail(product) })
  }

  build() {
    Column() {
      // 顶部栏：标题 + 购物车角标
      Row() {
        Text('精选课程').fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Stack({ alignContent: Alignment.TopEnd }) {
          Text('🛒').fontSize(24)
          if (this.cartCount > 0) {
            Text(`${this.cartCount}`)
              .fontSize(10)
              .fontColor(Color.White)
              .width(16)
              .height(16)
              .textAlign(TextAlign.Center)
              .backgroundColor('#FF4D4F')
              .borderRadius(8)
              .offset({ x: 4, y: -4 })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      // 商品网格
      Grid() {
        ForEach(MOCK_PRODUCTS, (product: Product) => {
          GridItem() {
            this.productCard(product)
          }
        })
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .padding({ left: 16, right: 16, bottom: 16 })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }
}
