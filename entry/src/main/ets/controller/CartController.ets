import { promptAction } from '@kit.ArkUI'
import { Product } from '../models/productModel'
import { CartState, getCartState } from '../viewmodel/CartState'

/**
 * 购物车控制器。
 *
 * 职责：把购物车页面的用户交互转发给全局 CartState（持久化单例）。
 * 不再持有页面级 ViewModel —— 全局 CartState 即数据源，
 * 关 App 重启后数据自动从 PersistenceV2 恢复，不需要 loadMockData。
 */
export class CartController {
  private cart: CartState = getCartState()

  /** + 按钮：加一件相同商品（直接 push） */
  increase(product: Product): void {
    this.cart.add(product)
  }

  /** - 按钮：减一件（移除第一个匹配项；减到 0 该商品自动从聚合列表消失） */
  decrease(productId: string): void {
    this.cart.removeOne(productId)
  }

  /** 左滑删除：移除全部相同 id 的项 */
  remove(productId: string): void {
    this.cart.remove(productId)
  }

  /** 去支付：暂时弹 Toast 占位，等支付/订单页接入后替换 */
  goPay(): void {
    promptAction.showToast({
      message: `去支付（共 ${this.cart.totalCount} 件，¥${this.cart.totalAmount}）`,
      duration: 1500
    })
  }
}
