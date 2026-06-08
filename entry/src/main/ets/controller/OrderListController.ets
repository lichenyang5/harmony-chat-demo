import { promptAction } from '@kit.ArkUI'
import { OrderBiz } from '../biz/OrderBiz'
import { getOrderState, OrderState } from '../viewmodel/OrderState'

/**
 * 订单列表页控制器。
 *
 * 数据源直接是全局 OrderState（持久化单例），不需要单独 ViewModel：
 * 列表渲染时 ForEach(orderState.orders)，新建/支付/取消任意一处变化
 * 自动响应式刷新。
 */
export class OrderListController {
  /** 全局订单单例（持久化），UI 直接读 orders 字段 */
  orderState: OrderState = getOrderState()

  private biz: OrderBiz = new OrderBiz()

  /** 点未支付订单"去支付" → 调 biz.pay 标记为 paid */
  async payOrder(orderId: string): Promise<void> {
    await this.biz.pay(orderId)
    promptAction.showToast({ message: '支付成功', duration: 1200 })
  }

  /** 点未支付订单"取消" → 标记为 cancelled */
  cancelOrder(orderId: string): void {
    this.orderState.cancel(orderId)
    promptAction.showToast({ message: '已取消订单', duration: 1200 })
  }

  /** 状态徽章文本 */
  statusLabel(status: string): string {
    if (status === 'paid') {
      return '已支付'
    }
    if (status === 'cancelled') {
      return '已取消'
    }
    return '待支付'
  }

  /** 创建时间格式化（YYYY-MM-DD HH:mm） */
  formatTime(ts: number): string {
    if (ts <= 0) {
      return ''
    }
    const d = new Date(ts)
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`)
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
  }
}
