import { HMRouterMgr, HMLifecycleState } from '@hadss/hmrouter'
import { Product } from '../models/productModel'
import { ProductDetailViewModel } from '../viewmodel/ProductDetailViewModel'
import { CartState, getCartState } from '../viewmodel/CartState'

/**
 * 商品详情页控制器。
 *
 * 职责：
 * - 路由传参解析（getCurrentParam → vm.product）
 * - 页面生命周期观察者注册/注销（演示 addObserver API）
 * - 加购数量本地选择（vm.addCount）
 * - 确认加购：按数量批量 push 到全局 CartState，然后 pop
 *
 * 与首页通信方式：
 * 旧版用 setPopParam + onResult 回调累加首页 cartCount；
 * 现在直接写入全局 CartState（持久化），首页角标自动同步。
 */
export class ProductDetailController {
  private vm: ProductDetailViewModel
  private cart: CartState = getCartState()

  constructor(vm: ProductDetailViewModel) {
    this.vm = vm
  }

  /**
   * 从路由传参中读取商品信息并写入 ViewModel。
   * 在 aboutToAppear 中调用；push 时 param 字段传入的对象即为 Product。
   */
  initFromParam(): void {
    const param = HMRouterMgr.getCurrentParam()
    if (param) {
      this.vm.product = param as Product
    }
  }

  /**
   * 向当前页面生命周期持有者注册三个观察者（onShown / onHidden / onDisAppear）。
   * 每次事件触发时，向 vm.lifecycleLog 追加一条带时间戳的日志。
   * 在 aboutToAppear 中调用。
   */
  initLifecycle(): void {
    const owner = HMRouterMgr.getCurrentLifecycleOwner()
    if (!owner) {
      return
    }

    owner.addObserver(HMLifecycleState.onShown, () => {
      this.appendLog('onShown ▶ 页面显示/从子页返回')
    })
    owner.addObserver(HMLifecycleState.onHidden, () => {
      this.appendLog('onHidden ⏸ 页面隐藏（跳转子页时）')
    })
    owner.addObserver(HMLifecycleState.onDisAppear, () => {
      this.appendLog('onDisAppear ✕ 页面销毁')
    })
  }

  /**
   * 移除全部生命周期观察者，防止内存泄漏。
   * 在 aboutToDisappear 中调用。
   */
  removeLifecycle(): void {
    const owner = HMRouterMgr.getCurrentLifecycleOwner()
    owner?.removeObserver(HMLifecycleState.onShown)
    owner?.removeObserver(HMLifecycleState.onHidden)
    owner?.removeObserver(HMLifecycleState.onDisAppear)
  }

  /** + 按钮：本地选定数量 +1（受库存上限约束） */
  addToCart(): void {
    if (this.vm.addCount < this.vm.product.stock) {
      this.vm.addCount++
    }
  }

  /** - 按钮：本地选定数量 -1（最小 0） */
  decreaseCart(): void {
    if (this.vm.addCount > 0) {
      this.vm.addCount--
    }
  }

  /**
   * 确认加购：把 product 按 addCount 次数批量 push 到全局 CartState，然后 pop。
   * PersistenceV2 会自动持久化，首页角标 / 购物车页同步更新。
   */
  confirmAndBack(): void {
    if (this.vm.addCount > 0) {
      this.cart.addN(this.vm.product, this.vm.addCount)
    }
    HMRouterMgr.pop()
  }

  /**
   * 追加一条带时间戳的日志到 vm.lifecycleLog。
   * 超过 5 条时移除最旧的一条（FIFO 环形缓冲）。
   */
  private appendLog(msg: string): void {
    const time = new Date().toLocaleTimeString()
    if (this.vm.lifecycleLog.length >= 5) {
      this.vm.lifecycleLog.shift()
    }
    this.vm.lifecycleLog.push(`[${time}] ${msg}`)
  }
}
