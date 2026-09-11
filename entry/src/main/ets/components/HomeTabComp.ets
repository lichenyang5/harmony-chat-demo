import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { Product } from '../models/productModel'
import { AuthPersist } from '../utils/AuthPersist'
import { ThemeState } from '../viewmodel/ThemeState'
import { HomeViewModel } from '../viewmodel/HomeViewModel'
import { HomeController } from '../controller/HomeController'
import { ProductCardComp } from './ProductCardComp'
import { EntryRoutes } from '../constants/EntryRoutes'
import { CartState, getCartState } from '../viewmodel/CartState'

/**
 * 首页 Tab 组件。
 *
 * 职责：纯 UI 渲染（顶部问候 + 搜索框 + AI 灵感瀑布流 + 购物车入口）。
 * 所有业务逻辑（路由跳转、拉取内容、搜索和高度分列）委托给 HomeController。
 *
 * 响应式说明：
 * - aboutToAppear 时 controller.loadProducts() 拉 /api/products → vm.products
 * - 内容瀑布流：Controller 估算完整卡片高度，并把下一项放入更短列
 * - 购物车角标：读全局单例 cart.totalCount，加购后自动同步
 */
@ComponentV2
export struct HomeTabComp {
  /** 首页视图状态（搜索关键词、商品列表、loading、error）*/
  @Local vm: HomeViewModel = new HomeViewModel()
  /** 全局购物车单例（持久化），用于角标显示 */
  @Local cart: CartState = getCartState()

  /** 来自父组件（HomePage）的登录凭证，用于展示用户名 */
  @Consumer() auth: AuthPersist = new AuthPersist()
  /** 来自父组件（HomePage）的全局主题，用于动态颜色 */
  @Consumer() theme: ThemeState = new ThemeState()

  private controller: HomeController = new HomeController(this.vm)

  aboutToAppear(): void {
    // 进首页时拉接口；切到其他 Tab 再回来不会重复触发（TabContent 保留实例）
    this.controller.loadProducts()
  }

  build() {
    Column() {
      // ── 顶部栏：问候语 + 购物车入口 ──────────────────────────────────
      Row() {
        Column({ space: 2 }) {
          Text(this.auth.userName ? `你好，${this.auth.userName}` : '你好，游客')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)

          Text('发现实用 AI 灵感')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 购物车图标 + 数量角标
        Stack({ alignContent: Alignment.TopEnd }) {
          Text('🛒')
            .fontSize(24)

          if (this.cart.totalCount > 0) {
            Text(`${this.cart.totalCount}`)
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
        .onClick(() => {
          HMRouterMgr.push({
            navigationId: NAV_ID,
            pageUrl: EntryRoutes.PAGE_CART
          })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor(this.theme.bg)

      // ── 搜索框 ──────────────────────────────────────────────────────
      Search({
        value: this.vm.searchKeyword,
        placeholder: '搜索提示词 / AI 助手'
      })
        .width('92%')
        .height(40)
        .margin({ bottom: 12 })
        .onChange((v: string) => {
          this.controller.updateSearchKeyword(v)
        })

      // ── 主区域：loading / error / 商品瀑布流 三选一 ────────────────────
      if (this.vm.loading && this.vm.products.length === 0) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(this.theme.primary)
          Text('正在加载灵感…')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.vm.error.length > 0 && this.vm.products.length === 0) {
        Column({ space: 12 }) {
          Text('😢').fontSize(48)
          Text(this.vm.error)
            .fontSize(13)
            .fontColor(this.theme.textSecondary)
          Button('重新加载')
            .backgroundColor(this.theme.primary)
            .fontColor(this.theme.onPrimary)
            .onClick(() => this.controller.loadProducts())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.vm.leftProducts.length === 0 && this.vm.rightProducts.length === 0) {
        Column({ space: 10 }) {
          Text('🔍').fontSize(42)
          Text('没有找到相关提示词或 AI 助手')
            .fontSize(13)
            .fontColor(this.theme.textSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Row({ space: 12 }) {
            Column({ space: 12 }) {
              ForEach(
                this.vm.leftProducts,
                (product: Product) => {
                  ProductCardComp({
                    product: product,
                    onTap: (p: Product) => { this.controller.goDetail(p) }
                  })
                },
                (p: Product) => p.id
              )
            }
            .layoutWeight(1)

            Column({ space: 12 }) {
              ForEach(
                this.vm.rightProducts,
                (product: Product) => {
                ProductCardComp({
                  product: product,
                  onTap: (p: Product) => { this.controller.goDetail(p) }
                })
                },
                (p: Product) => p.id
              )
            }
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .backgroundColor(this.theme.bg)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
