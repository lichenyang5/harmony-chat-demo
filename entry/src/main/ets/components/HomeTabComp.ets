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
 * 职责：纯 UI 渲染（顶部问候 + 搜索框 + 商品网格 + 购物车入口）。
 * 所有业务逻辑（路由跳转、搜索过滤）委托给 HomeController。
 *
 * 响应式说明：
 * - 商品网格：build 调 `controller.getFilteredProducts()`，内部访问 vm.searchKeyword
 *   自动建立依赖；关键词变化时 build 重跑、Grid 自动过滤。
 * - 购物车角标：读全局单例 cart.totalCount，详情页加购或购物车页删改后自动同步。
 */
@ComponentV2
export struct HomeTabComp {
  /** 首页视图状态（搜索关键词） */
  @Local vm: HomeViewModel = new HomeViewModel()
  /** 全局购物车单例（持久化），用于角标显示 */
  @Local cart: CartState = getCartState()

  /** 来自父组件（HomePage）的登录凭证，用于展示用户名 */
  @Consumer() auth: AuthPersist = new AuthPersist()
  /** 来自父组件（HomePage）的全局主题，用于动态颜色 */
  @Consumer() theme: ThemeState = new ThemeState()

  private controller: HomeController = new HomeController(this.vm)

  build() {
    Column() {
      // ── 顶部栏：问候语 + 购物车入口 ──────────────────────────────────
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

        // 购物车图标 + 数量角标（数字来自全局 CartState.totalCount）
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
        placeholder: '搜索商品 / 教程'
      })
        .width('92%')
        .height(40)
        .margin({ bottom: 12 })
        .onChange((v: string) => {
          this.vm.searchKeyword = v
        })

      // ── 商品网格（两列）─────────────────────────────────────────────
      Grid() {
        ForEach(
          this.controller.getFilteredProducts(),
          (product: Product) => {
            GridItem() {
              ProductCardComp({
                product: product,
                onTap: (p: Product) => { this.controller.goDetail(p) }
              })
            }
          },
          (p: Product) => p.id
        )
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
