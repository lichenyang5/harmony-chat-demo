import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouterMgr, HMPopInfo } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { Product, MOCK_PRODUCTS } from '../models/productModel'
import { AuthPersist } from '../utils/AuthPersist'
import { ThemeState } from '../viewmodel/ThemeState'

@ComponentV2
export struct HomeTabComp {
  @Local cartCount: number = 0
  @Consumer() auth: AuthPersist = new AuthPersist()
  @Consumer() theme: ThemeState = new ThemeState()

  private goDetail(product: Product): void {
    HMRouterMgr.push(
      {
        navigationId: NAV_ID,
        pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL,
        param: product
      },
      {
        onResult: (popInfo: HMPopInfo) => {
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
          .backgroundColor(this.theme.placeholderBg)   // ← 主题色
          .borderRadius(8)

        Text(product.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)            // ← 主题色
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(product.desc)
          .fontSize(11)
          .fontColor(this.theme.textSecondary)          // ← 主题色
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`¥${product.price}`)
          .fontSize(15)
          .fontColor('#FF4D4F')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding(10)
      .backgroundColor(this.theme.surface)              // ← 主题色
      .borderRadius(12)
      .shadow({ radius: 4, color: '#0A000000', offsetY: 2 })

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
      // 顶部栏
      Row() {
        Column({ space: 2 }) {
          Text(this.auth.userName ? `你好，${this.auth.userName}` : '你好，游客')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)          // ← 主题色
          Text('欢迎来到精选课程')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)        // ← 主题色
        }
        .alignItems(HorizontalAlign.Start)

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
    .backgroundColor(this.theme.bg)                     // ← 主题色
  }
}
