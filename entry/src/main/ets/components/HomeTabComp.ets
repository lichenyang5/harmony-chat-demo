import { Product, MOCK_PRODUCTS } from '../models/productModel'
import { AuthPersist } from '../utils/AuthPersist'
import { ThemeState } from '../viewmodel/ThemeState'
import { HomeViewModel } from '../viewmodel/HomeViewModel'
import { HomeController } from '../controller/HomeController'

/**
 * 首页 Tab 组件。
 *
 * 职责：纯 UI 渲染（商品网格、购物车角标、用户问候语）。
 * 导航跳转和加购计数逻辑委托给 HomeController。
 */
@ComponentV2
export struct HomeTabComp {
  /** 首页视图状态（购物车数量），由 controller 通过 onResult 回调累加 */
  @Local vm: HomeViewModel = new HomeViewModel()

  /** 来自父组件（HomePage）的登录凭证，用于展示用户名 */
  @Consumer() auth: AuthPersist = new AuthPersist()
  /** 来自父组件（HomePage）的全局主题，用于动态颜色 */
  @Consumer() theme: ThemeState = new ThemeState()

  private controller: HomeController = new HomeController(this.vm)

  // ─── UI ───────────────────────────────────────────────────────────────────

  /**
   * 单个商品卡片的 @Builder 模板。
   * 点击时调用 controller.goDetail 跳转到详情页，
   * 并在 onResult 中累加购物车数量。
   */
  @Builder
  productCard(product: Product) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 6 }) {
        // 图片占位块
        Row()
          .width('100%')
          .height(80)
          .backgroundColor(this.theme.placeholderBg)
          .borderRadius(8)

        Text(product.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(product.desc)
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`¥${product.price}`)
          .fontSize(15)
          .fontColor(this.theme.danger)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding(10)
      .backgroundColor(this.theme.surface)
      .borderRadius(12)
      .shadow({
        radius: 4,
        color: this.theme.shadowColor,
        offsetY: 2
      })

      // 标签角标（如"限时"、"新品"等）
      if (product.tag) {
        Text(product.tag)
          .fontSize(10)
          .fontColor(this.theme.onPrimary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.theme.primary)
          .borderRadius({ topRight: 12, bottomLeft: 8 })
      }
    }
    .onClick(() => {
      // 跳转详情页；controller 内部注册 onResult，pop 时累加购物车
      this.controller.goDetail(product)
    })
  }

  build() {
    Column() {
      // ── 顶部栏：问候语 + 购物车角标 ──────────────────────────────────
      Row() {
        Column({ space: 2 }) {
          Text(this.auth.userName ? `你好，${this.auth.userName}` : '你好，游客')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)

          Text('欢迎来到精选课程')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 购物车图标 + 数量角标
        Stack({ alignContent: Alignment.TopEnd }) {
          Text('🛒')
            .fontSize(24)

          if (this.vm.cartCount > 0) {
            Text(`${this.vm.cartCount}`)
              .fontSize(10)
              .fontColor(this.theme.onDanger)
              .width(16)
              .height(16)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.theme.danger)
              .borderRadius(8)
              .offset({ x: 4, y: -4 })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor(this.theme.bg)

      // ── 商品网格（两列）─────────────────────────────────────────────
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
      .backgroundColor(this.theme.bg)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
