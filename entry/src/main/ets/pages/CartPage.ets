import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { getThemeState, ThemeState } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { CartController } from '../controller/CartController'
import { CartItem, CartViewModel } from '../viewmodel/CartViewModel'

/**
 * 购物车页面。
 *
 * 职责：纯 UI 渲染。增删改逻辑全部委托给 CartController；
 * 合计金额/件数由 CartViewModel 的 getter 实时计算（响应式）。
 *
 * 结构：
 * - 顶部 NavBar
 * - 中间区域：if items 为空 → 空状态；否则 → List（支持左滑删除）
 * - 底部支付栏（合计 + 去支付按钮）
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_CART })
@ComponentV2
export struct CartPage {
  /** 页面视图状态（购物车条目） */
  @Local vm: CartViewModel = new CartViewModel()
  /** 全局主题，用于动态颜色 */
  @Local theme: ThemeState = getThemeState()

  private controller: CartController = new CartController(this.vm)

  /**
   * 左滑出现的删除按钮 @Builder。
   * ListItem 的 swipeAction.end 需要一个 Builder，参数 productId 由外层 ForEach 闭包传入。
   */
  @Builder
  deleteBuilder(productId: string) {
    Row() {
      Button('删除')
        .backgroundColor(this.theme.danger)
        .fontColor(this.theme.onDanger)
        .height(80)
        .onClick(() => this.controller.remove(productId))
    }
    .padding({ left: 12 })
    .height('100%')
  }

  build() {
    Column() {
      // ── 顶部 NavBar ──────────────────────────────────────────────────
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(this.theme.textPrimary)
          .padding(12)
          .onClick(() => HMRouterMgr.pop())

        Text('购物车')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      // ── 中间区域：空状态 / 列表 二选一 ───────────────────────────────
      if (this.vm.items.length === 0) {
        // 空状态
        Column({ space: 12 }) {
          Text('🛒').fontSize(80)
          Text('购物车还是空的')
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
        // 商品列表
        List({ space: 12 }) {
          ForEach(this.vm.items, (item: CartItem) => {
            ListItem() {
              Row({ space: 12 }) {
                // 缩略图
                Image($rawfile(item.image))
                  .width(80)
                  .height(80)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)

                // 中间：名称 + 单价
                Column({ space: 6 }) {
                  Text(item.productName)
                    .fontSize(14)
                    .fontColor(this.theme.textPrimary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`¥${item.price}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.danger)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 右侧：数量加减
                Row({ space: 8 }) {
                  Button('-')
                    .width(28)
                    .height(28)
                    .fontSize(14)
                    .backgroundColor(this.theme.secondaryButtonBg)
                    .fontColor(this.theme.secondaryButtonText)
                    .onClick(() => this.controller.decrease(item.productId))

                  Text(`${item.count}`)
                    .fontSize(14)
                    .width(24)
                    .textAlign(TextAlign.Center)
                    .fontColor(this.theme.textPrimary)

                  Button('+')
                    .width(28)
                    .height(28)
                    .fontSize(14)
                    .backgroundColor(this.theme.primary)
                    .fontColor(this.theme.onPrimary)
                    .onClick(() => this.controller.increase(item.productId))
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.theme.surface)
              .borderRadius(12)
            }
            .swipeAction({ end: this.deleteBuilder(item.productId) })
          }, (item: CartItem) => item.productId)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12 })
      }

      // ── 底部支付栏 ──────────────────────────────────────────────────
      Row() {
        Column({ space: 2 }) {
          Text(`合计 ¥${this.vm.totalAmount}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.danger)

          Text(`共 ${this.vm.totalCount} 件`)
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('去支付')
          .height(40)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.onPrimary)
          .enabled(this.vm.items.length > 0)
          .onClick(() => this.controller.goPay())
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.theme.surface)
      .border({ width: { top: 0.5 }, color: this.theme.divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
