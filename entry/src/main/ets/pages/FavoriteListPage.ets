import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { EntryRoutes } from '../constants/EntryRoutes'
import { getThemeState, ThemeState } from '../viewmodel/ThemeState'
import { Product } from '../models/productModel'
import { ProductCardComp } from '../components/ProductCardComp'
import { FavoriteListViewModel } from '../viewmodel/FavoriteListViewModel'
import { FavoriteListController } from '../controller/FavoriteListController'

/**
 * 我的收藏页。
 *
 * 数据流：
 * - aboutToAppear → controller.loadAndFilter（拉商品全表 → filter 收藏 id）
 * - ProductCardComp 上的心形 toggle 直接改 FavoriteState
 *   ⇒ 这里 vm.products 不会自动 filter 掉，但卡片心形会变空心。
 *   返回再进就重新拉取过滤，符合"收藏页是快照"的语义。
 *
 * @Provider() theme：因为 ProductCardComp 内部用 @Consumer 拿主题，
 * 必须在祖先组件提供。
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_FAVORITE_LIST })
@ComponentV2
export struct FavoriteListPage {
  @Local vm: FavoriteListViewModel = new FavoriteListViewModel()

  /**
   * 给 ProductCardComp 透传主题：
   * @Provider/@Consumer V2 按"字段名"匹配 alias，必须叫 theme 才能让
   * ProductCardComp 的 @Consumer() theme 拿到。本组件内部直接 this.theme 也能用。
   */
  @Provider() theme: ThemeState = getThemeState()

  private controller: FavoriteListController = new FavoriteListController(this.vm)

  aboutToAppear(): void {
    this.controller.loadAndFilter()
  }

  build() {
    Column() {
      // ── NavBar ────────────────────────────────────────────────────────
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(this.theme.textPrimary)
          .padding(12)
          .onClick(() => HMRouterMgr.pop())

        Text('我的收藏')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      // ── 主区域 ────────────────────────────────────────────────────────
      if (this.vm.loading) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.theme.primary)
          Text('加载中…')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.vm.products.length === 0) {
        Column({ space: 12 }) {
          Text('♡').fontSize(72).fontColor(this.theme.textTertiary)
          Text('还没有收藏哦')
            .fontSize(14)
            .fontColor(this.theme.textSecondary)
          Button('去逛逛')
            .backgroundColor(this.theme.primary)
            .fontColor(this.theme.onPrimary)
            .onClick(() => HMRouterMgr.pop())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          ForEach(this.vm.products, (product: Product) => {
            GridItem() {
              ProductCardComp({
                product: product,
                onTap: (p: Product) => { this.controller.goDetail(p) }
              })
            }
          }, (p: Product) => p.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.theme.bg)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
