import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { EntryRoutes } from '../constants/EntryRoutes'
import { getThemeState, ThemeState } from '../viewmodel/ThemeState'
import { CheckoutViewModel } from '../viewmodel/CheckoutViewModel'
import { CheckoutController } from '../controller/CheckoutController'
import { OrderItem } from '../models/orderModel'
import { AuthPersist, getAuthPersist } from '../utils/AuthPersist'

/**
 * 结算 / 支付页。
 *
 * 进来时根据当前购物车快照生成 Order（unpaid）写入 OrderState；
 * 点立即支付 → 模拟支付 → 标记 paid → 清空购物车 → replace 到订单列表。
 *
 * 受 AuthInterceptor 保护：未登录时跳转此页会被拦截。
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_CHECKOUT, interceptors: ['AuthInterceptor'] })
@ComponentV2
export struct CheckoutPage {
  @Local vm: CheckoutViewModel = new CheckoutViewModel()
  @Local theme: ThemeState = getThemeState()
  @Local auth: AuthPersist = getAuthPersist()

  private controller: CheckoutController = new CheckoutController(this.vm)

  aboutToAppear(): void {
    this.controller.initOrder()
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

        Text('确认订单')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      // ── 主区域：空态 / 订单详情 ──────────────────────────────────────
      if (!this.vm.hasOrder) {
        Column({ space: 12 }) {
          Text('🛒').fontSize(60)
          Text('购物车为空，无法结算')
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
        Scroll() {
          Column({ space: 12 }) {
            // ── 收货地址（mock） ─────────────────────────────────────
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                Text('📍').fontSize(18)
                Text(this.auth.userName || '收货人')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.textPrimary)
                Text('138 0000 0000')
                  .fontSize(13)
                  .fontColor(this.theme.textSecondary)
              }
              .width('100%')

              Text('鸿蒙未来城 · ArkTS 大道 8 号 · ArkUI 公寓 2F')
                .fontSize(13)
                .fontColor(this.theme.textSecondary)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.theme.surface)
            .borderRadius(12)

            // ── 订单条目 ────────────────────────────────────────────
            Column({ space: 10 }) {
              ForEach(this.vm.order.items, (item: OrderItem) => {
                Row({ space: 12 }) {
                  Image($rawfile(item.image))
                    .width(64)
                    .height(64)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)

                  Column({ space: 6 }) {
                    Text(item.name)
                      .fontSize(14)
                      .fontColor(this.theme.textPrimary)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(`¥${item.price} × ${item.count}`)
                      .fontSize(12)
                      .fontColor(this.theme.textSecondary)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(`¥${item.price * item.count}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.danger)
                }
                .width('100%')
              }, (item: OrderItem) => item.productId)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.theme.surface)
            .borderRadius(12)

            // ── 金额汇总 ────────────────────────────────────────────
            Column({ space: 8 }) {
              Row() {
                Text('商品总价').fontSize(13).fontColor(this.theme.textSecondary)
                Blank()
                Text(`¥${this.vm.order.totalAmount}`)
                  .fontSize(13)
                  .fontColor(this.theme.textPrimary)
              }
              .width('100%')

              Row() {
                Text('运费').fontSize(13).fontColor(this.theme.textSecondary)
                Blank()
                Text('免运费').fontSize(13).fontColor(this.theme.textPrimary)
              }
              .width('100%')

              Divider()
                .color(this.theme.divider)
                .margin({ top: 4, bottom: 4 })

              Row() {
                Text('应付金额').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.theme.textPrimary)
                Blank()
                Text(`¥${this.vm.order.totalAmount}`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.danger)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.theme.surface)
            .borderRadius(12)
          }
          .padding({ left: 12, right: 12, top: 12, bottom: 100 })
        }
        .layoutWeight(1)
      }

      // ── 底部支付栏 ────────────────────────────────────────────────────
      Row() {
        Column({ space: 2 }) {
          Text(`合计 ¥${this.vm.hasOrder ? this.vm.order.totalAmount : 0}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.danger)
          Text(`共 ${this.vm.hasOrder ? this.vm.order.totalCount : 0} 件`)
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button(this.vm.paying ? '支付中…' : '立即支付')
          .height(44)
          .backgroundColor(this.vm.hasOrder ? this.theme.primary : this.theme.disabledBg)
          .fontColor(this.theme.onPrimary)
          .enabled(this.vm.hasOrder && !this.vm.paying)
          .onClick(() => this.controller.pay())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      .backgroundColor(this.theme.surface)
      .border({ width: { top: 0.5 }, color: this.theme.divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
