import { HMRouterMgr } from '@hadss/hmrouter'
import { promptAction } from '@kit.ArkUI'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { CartState, getCartState } from '../viewmodel/CartState'
import { OrderBiz } from '../biz/OrderBiz'
import { CheckoutViewModel } from '../viewmodel/CheckoutViewModel'

/**
 * 结算页控制器。
 *
 * 流程：
 * 1. aboutToAppear → initOrder：根据当前购物车生成 unpaid Order，写入 OrderState
 * 2. 用户点"立即支付" → pay：调 biz.pay 标记 paid → 清空购物车 → replace 跳订单列表
 *
 * 注：用 replace 而非 push，避免支付后用户点返回又回到 Checkout 看到旧订单。
 */
export class CheckoutController {
  private vm: CheckoutViewModel
  private cart: CartState = getCartState()
  private biz: OrderBiz = new OrderBiz()

  constructor(vm: CheckoutViewModel) {
    this.vm = vm
  }

  /** 进入结算页时生成订单（购物车为空则显示空态） */
  initOrder(): void {
    if (this.cart.totalCount === 0) {
      this.vm.hasOrder = false
      return
    }
    this.vm.order = this.biz.createFromCart(this.cart)
    this.vm.hasOrder = true
  }

  /**
   * 点"立即支付"：
   * 1. paying 置位避免重复点击
   * 2. biz.pay 模拟服务端支付（800ms 后 markPaid）
   * 3. 清空购物车（避免用户再次结算同一批）
   * 4. replace 到订单列表
   */
  async pay(): Promise<void> {
    if (!this.vm.hasOrder || this.vm.paying) {
      return
    }
    this.vm.paying = true
    try {
      await this.biz.pay(this.vm.order.id)
      this.cart.clear()
      promptAction.showToast({ message: '支付成功', duration: 1200 })
      HMRouterMgr.replace({
        navigationId: NAV_ID,
        pageUrl: EntryRoutes.PAGE_ORDER_LIST
      })
    } finally {
      this.vm.paying = false
    }
  }
}
