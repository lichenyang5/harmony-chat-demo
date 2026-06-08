import { CartState } from '../viewmodel/CartState'
import { Order, OrderItem } from '../models/orderModel'
import { getOrderState, OrderState } from '../viewmodel/OrderState'

/**
 * 订单业务层。
 *
 * 这里把"从购物车生成订单"和"模拟支付"两步收口，
 * 让 controller / page 只关心业务结果。
 *
 * 当前是纯本地模拟：
 * - createFromCart：把 cart.getGrouped() 转成 OrderItem[]，
 *   生成 unpaid 订单并写入 OrderState
 * - pay：setTimeout 800ms 后 markPaid（模拟服务端确认支付）
 *
 * 后续若接服务端 /api/orders 只需替换 pay 实现，上层不动。
 */
export class OrderBiz {
  private orderState: OrderState = getOrderState()

  /**
   * 从购物车创建订单：聚合 cart 中的 items（按 id 合并 count），写入 OrderState。
   * 返回新建的 Order 对象。
   */
  createFromCart(cart: CartState): Order {
    const grouped = cart.getGrouped()

    const order = new Order()
    order.id = `O${Date.now()}`
    order.createTime = Date.now()
    order.status = 'unpaid'
    order.totalCount = cart.totalCount
    order.totalAmount = cart.totalAmount

    const items: OrderItem[] = []
    for (const g of grouped) {
      const item = new OrderItem()
      item.productId = g.product.id
      item.name = g.product.name
      item.price = g.product.price
      item.image = g.product.image
      item.count = g.count
      items.push(item)
    }
    order.items = items

    this.orderState.create(order)
    return order
  }

  /**
   * 模拟支付：800ms 后把订单标记为 paid。
   * 真接服务端时这里改成 HttpUtil.post('/api/pay', { orderId })。
   */
  pay(orderId: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      setTimeout(() => {
        this.orderState.markPaid(orderId)
        resolve(true)
      }, 800)
    })
  }
}
