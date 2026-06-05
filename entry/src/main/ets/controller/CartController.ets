import { promptAction } from '@kit.ArkUI'
import { MOCK_PRODUCTS } from '../models/productModel'
import { CartItem, CartViewModel } from '../viewmodel/CartViewModel'

/**
 * 购物车控制器。
 *
 * 职责：
 * - 启动时塞 3 条假数据（Step 3 接持久化后这段会替换为"从持久化读取"）
 * - 增 / 删 / 改购物车条目
 * - 触发"去支付"
 */
export class CartController {
  private vm: CartViewModel

  constructor(vm: CartViewModel) {
    this.vm = vm
    this.loadMockData()
  }

  /**
   * 临时假数据：从 MOCK_PRODUCTS 取前 3 个商品做成 CartItem 推入 vm.items。
   * Step 3 接入 PersistenceV2 后，这个方法会被替换为"从持久化读取"。
   */
  private loadMockData(): void {
    const picked = MOCK_PRODUCTS.slice(0, 3)
    picked.forEach((p) => {
      const item = new CartItem()
      item.productId = p.id
      item.productName = p.name
      item.price = p.price
      item.image = p.image
      item.count = 1
      this.vm.items.push(item)
    })
  }

  /**
   * 移除指定商品。用 filter 返回新数组而不是 splice ——
   * V2 下数组重新赋值能可靠触发 ForEach 重新计算 keyGenerator。
   */
  remove(productId: string): void {
    this.vm.items = this.vm.items.filter((i) => i.productId !== productId)
  }

  /** 数量 +1。CartItem 是 @ObservedV2 + @Trace，count 修改自动响应 UI 与 totalCount/totalAmount。 */
  increase(productId: string): void {
    const item = this.vm.items.find((i) => i.productId === productId)
    if (item) {
      item.count++
    }
  }

  /** 数量 -1，最小为 1（再小就该用 remove 而不是 decrease）。 */
  decrease(productId: string): void {
    const item = this.vm.items.find((i) => i.productId === productId)
    if (item && item.count > 1) {
      item.count--
    }
  }

  /** 去支付：暂时弹 Toast 占位，等支付/订单页接入后替换。 */
  goPay(): void {
    promptAction.showToast({
      message: `去支付（共 ${this.vm.totalCount} 件，¥${this.vm.totalAmount}）`,
      duration: 1500
    })
  }
}
