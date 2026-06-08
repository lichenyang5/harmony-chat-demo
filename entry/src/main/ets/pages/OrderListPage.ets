import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { EntryRoutes } from '../constants/EntryRoutes'
import { getThemeState, ThemeState } from '../viewmodel/ThemeState'
import { OrderListController } from '../controller/OrderListController'
import { Order, OrderItem } from '../models/orderModel'

/**
 * 我的订单页。
 *
 * 数据源：全局 OrderState（PersistenceV2 持久化），无需本地 ViewModel。
 * 列表按 createTime 倒序（新建时 unshift 进数组头）。
 *
 * 受 AuthInterceptor 保护：未登录无法访问。
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_ORDER_LIST, interceptors: ['AuthInterceptor'] })
@ComponentV2
export struct OrderListPage {
  @Local theme: ThemeState = getThemeState()

  private controller: OrderListController = new OrderListController()

  /**
   * 状态徽章颜色（已支付绿、已取消灰、待支付主色）。
   * 注：success 颜色 ThemeState 没定义，这里直接用绿色字面量；
   * 后续若 ThemeState 加 success 字段可统一替换。
   */
  statusColor(status: string): ResourceColor {
    if (status === 'paid') {
      return '#52C41A'
    }
    if (status === 'cancelled') {
      return this.theme.textTertiary
    }
    return this.theme.primary
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

        Text('我的订单')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      // ── 主区域：空态 / 列表 ──────────────────────────────────────────
      if (this.controller.orderState.orders.length === 0) {
        Column({ space: 12 }) {
          Text('📦').fontSize(64)
          Text('暂无订单')
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
        List({ space: 12 }) {
          ForEach(this.controller.orderState.orders, (order: Order) => {
            ListItem() {
              Column({ space: 8 }) {
                // 头部：订单号 + 状态徽章
                Row() {
                  Text(`单号 ${order.id}`)
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                  Blank()
                  Text(this.controller.statusLabel(order.status))
                    .fontSize(12)
                    .fontColor(this.statusColor(order.status))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .border({ width: 1, color: this.statusColor(order.status) })
                    .borderRadius(10)
                }
                .width('100%')

                // 商品缩略图（最多 3 个，超出显示 +N）
                Row({ space: 6 }) {
                  ForEach(order.items.slice(0, 3), (item: OrderItem) => {
                    Image($rawfile(item.image))
                      .width(56)
                      .height(56)
                      .borderRadius(6)
                      .objectFit(ImageFit.Cover)
                  }, (item: OrderItem) => item.productId)

                  if (order.items.length > 3) {
                    Text(`+${order.items.length - 3}`)
                      .fontSize(12)
                      .fontColor(this.theme.textSecondary)
                      .width(56)
                      .height(56)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(this.theme.surface)
                      .border({ width: 1, color: this.theme.divider })
                      .borderRadius(6)
                  }
                }
                .width('100%')

                // 时间 + 金额
                Row() {
                  Text(this.controller.formatTime(order.createTime))
                    .fontSize(11)
                    .fontColor(this.theme.textTertiary)
                  Blank()
                  Text(`共 ${order.totalCount} 件   合计`)
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                  Text(`¥${order.totalAmount}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.danger)
                    .margin({ left: 4 })
                }
                .width('100%')

                // 仅未支付订单显示操作按钮
                if (order.status === 'unpaid') {
                  Row({ space: 12 }) {
                    Blank()
                    Button('取消')
                      .height(32)
                      .fontSize(12)
                      .backgroundColor(this.theme.secondaryButtonBg)
                      .fontColor(this.theme.secondaryButtonText)
                      .onClick(() => this.controller.cancelOrder(order.id))
                    Button('去支付')
                      .height(32)
                      .fontSize(12)
                      .backgroundColor(this.theme.primary)
                      .fontColor(this.theme.onPrimary)
                      .onClick(() => this.controller.payOrder(order.id))
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.theme.surface)
              .borderRadius(12)
            }
          }, (order: Order) => order.id)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
