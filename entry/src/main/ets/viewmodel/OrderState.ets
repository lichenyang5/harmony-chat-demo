import { PersistenceV2, Type } from '@kit.ArkUI'
import { Order } from '../models/orderModel'

/**
 * 全局订单状态。
 *
 * 设计：
 * - orders 数组按 createTime 倒序（最新订单排前），新建订单 unshift 进数组
 * - 持久化：@Type(Order) 告诉 PersistenceV2 反序列化时还原成 Order 类
 *   （否则会变成普通对象，丢失原型）。
 * - 修改时**整体替换**新数组才触发 V2 响应（参考 [[CartState]] / [[FavoriteState]] 写法）。
 *
 * 使用：
 * ```ts
 * const os = getOrderState()
 * os.create(order)         // 下单时调
 * os.markPaid(orderId)     // 支付成功
 * os.findById(id)          // 订单详情
 * os.unpaidCount           // 个人中心待支付角标
 * ```
 */
@ObservedV2
export class OrderState {
  /** 订单列表（按 createTime 倒序） */
  @Trace @Type(Order) orders: Order[] = []

  /** 待支付订单数（个人中心红点用） */
  get unpaidCount(): number {
    return this.orders.filter((o) => o.status === 'unpaid').length
  }

  /** 创建订单：unshift 到数组头（最新排前） */
  create(order: Order): void {
    const next = this.orders.slice()
    next.unshift(order)
    this.orders = next
  }

  /** 按 id 查询订单 */
  findById(id: string): Order | undefined {
    return this.orders.find((o) => o.id === id)
  }

  /** 标记订单为已支付 */
  markPaid(id: string): void {
    this.orders = this.orders.map((o) => {
      if (o.id === id) {
        o.status = 'paid'
      }
      return o
    })
  }

  /** 取消订单 */
  cancel(id: string): void {
    this.orders = this.orders.map((o) => {
      if (o.id === id) {
        o.status = 'cancelled'
      }
      return o
    })
  }

  /** 清空所有订单（仅本地，演示用） */
  clear(): void {
    this.orders = []
  }
}

/**
 * 获取全局订单单例。PersistenceV2 用 key 'OrderState' 持久化。
 */
export function getOrderState(): OrderState {
  return PersistenceV2.connect(OrderState, 'OrderState', () => new OrderState())!
}
