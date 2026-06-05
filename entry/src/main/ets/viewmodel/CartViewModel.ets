/**
 * 购物车视图状态（页面级）。
 *
 * @ObservedV2 + @Trace 提供响应式能力：
 * - items 数组本身变化（增删）→ 触发 ForEach 重渲染
 * - 单个 CartItem.count 变化 → 触发 totalCount/totalAmount getter 重算
 *
 * 当前是页面级状态；Step 3 升级为 PersistenceV2 持久化的全局 CartState 后，
 * 关 App 重启购物车还在，并被首页角标共享。
 */

@ObservedV2
export class CartItem {
  /** 商品 ID（主键，去重判断） */
  @Trace productId: string = ''
  /** 商品名称（购物车快照，避免后续反查 Product 表） */
  @Trace productName: string = ''
  /** 单价（快照） */
  @Trace price: number = 0
  /** 图片路径（快照，形如 'images/1.png'） */
  @Trace image: string = ''
  /** 购买数量（最小 1，到 0 应当 remove） */
  @Trace count: number = 1
}

@ObservedV2
export class CartViewModel {
  /** 购物车条目数组。Step 3 升级为 @Type(CartItem) 配合 PersistenceV2 反序列化 */
  @Trace items: CartItem[] = []

  /** 商品总件数（所有 item.count 之和） */
  get totalCount(): number {
    return this.items.reduce((sum, i) => sum + i.count, 0)
  }

  /** 合计金额（所有 item.count * item.price 之和） */
  get totalAmount(): number {
    return this.items.reduce((sum, i) => sum + i.count * i.price, 0)
  }
}
