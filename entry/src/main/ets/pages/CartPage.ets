import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { getThemeState, ThemeState } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { CartController } from '../controller/CartController'
import { CartState, getCartState, GroupedCartItem } from '../viewmodel/CartState'

/**
 * 购物车页面。
 *
 * 数据源：全局持久化的 CartState（PersistenceV2 单例）。
 * 同一商品多次加购在 items 数组里出现多次，UI 用 cart.getGrouped()
 * 聚合后展示，count 是同 id 出现的次数。
 *
 * 交互：
 * - + 按钮 → CartController.increase(product) → cart.add(product)
 * - - 按钮 → CartController.decrease(id) → cart.removeOne(id)（减到 0 自动从聚合列表消失）
 * - 左滑删除 → CartController.remove(id) → cart.remove(id) 移除全部相同 id
 * - 去支付 → 暂时 Toast 占位
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_CART })
@ComponentV2
export struct CartPage {
  /** 全局购物车单例（持久化 + 响应式） */
  @Local cart: CartState = getCartState()
  /** 全局主题 */
  @Local theme: ThemeState = getThemeState()

  private controller: CartController = new CartController()

  /**
   * 左滑出现的删除按钮 @Builder。
   * 点击调用 controller.remove 删除该 productId 全部条目。
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

      // ── 中间区域：空 / 列表 二选一 ───────────────────────────────────
      if (this.cart.items.length === 0) {
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
        // 聚合后的商品列表（同 id 合并）
        List({ space: 12 }) {
          ForEach(this.cart.getGrouped(), (item: GroupedCartItem) => {
            ListItem() {
              Row({ space: 12 }) {
                // 缩略图
                Image($rawfile(item.product.image))
                  .width(80)
                  .height(80)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)

                // 中间：名称 + 单价
                Column({ space: 6 }) {
                  Text(item.product.name)
                    .fontSize(14)
                    .fontColor(this.theme.textPrimary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`¥${item.product.price}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.danger)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 右侧：数量加减
                //
                // Button 默认 type 是 Capsule/ROUNDED_RECTANGLE，自带较大 padding，
                // 28vp 这种小按钮文字会被裁掉；必须设 type(Normal) + padding(0)
                // 自己控圆角，才能让"-"/"+"正常居中显示。
                Row({ space: 8 }) {
                  Button('-')
                    .type(ButtonType.Normal)
                    .borderRadius(14)
                    .padding(0)
                    .width(28)
                    .height(28)
                    .fontSize(16)
                    .backgroundColor(this.theme.secondaryButtonBg)
                    .fontColor(this.theme.secondaryButtonText)
                    .onClick(() => this.controller.decrease(item.product.id))

                  Text(`${item.count}`)
                    .fontSize(14)
                    .width(24)
                    .textAlign(TextAlign.Center)
                    .fontColor(this.theme.textPrimary)

                  Button('+')
                    .type(ButtonType.Normal)
                    .borderRadius(14)
                    .padding(0)
                    .width(28)
                    .height(28)
                    .fontSize(16)
                    .backgroundColor(this.theme.primary)
                    .fontColor(this.theme.onPrimary)
                    .onClick(() => this.controller.increase(item.product))
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.theme.surface)
              .borderRadius(12)
            }
            .swipeAction({ end: this.deleteBuilder(item.product.id) })
          }, (item: GroupedCartItem) => item.product.id)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12 })
      }

      // ── 底部支付栏 ──────────────────────────────────────────────────
      Row() {
        Column({ space: 2 }) {
          Text(`合计 ¥${this.cart.totalAmount}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.danger)

          Text(`共 ${this.cart.totalCount} 件`)
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('去支付')
          .height(40)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.onPrimary)
          .enabled(this.cart.items.length > 0)
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
