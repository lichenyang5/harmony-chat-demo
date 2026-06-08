/**
 * 订单条目（订单内的一种商品聚合）。
 *
 * 设计：不直接持有 Product 类，而是把名称/价格/图等冗余进来，
 * 避免商品上下架后历史订单无法显示。这是电商订单的常见做法。
 */
export class OrderItem {
  productId: string = ''
  name: string = ''
  price: number = 0
  image: string = ''
  count: number = 0
}

/**
 * 订单。
 *
 * status: 'unpaid' | 'paid' | 'cancelled'
 * 为简化未引入联合字面量类型，用普通 string 字段，约定取值。
 */
export class Order {
  id: string = ''
  status: string = 'unpaid'       // 'unpaid' / 'paid' / 'cancelled'
  totalAmount: number = 0
  totalCount: number = 0
  createTime: number = 0
  items: OrderItem[] = []
}
