import { HMRouterMgr, HMLifecycleState } from '@hadss/hmrouter'
import { Product } from '../models/productModel'
import { ProductDetailViewModel } from '../viewmodel/ProductDetailViewModel'

/**
 * 商品详情页控制器。
 *
 * 职责：
 * - 路由传参解析（getCurrentParam → vm.product）
 * - 页面生命周期观察者注册/注销（演示 addObserver API）
 * - 加购数量管理，并通过 setPopParam 实时通知上一页
 * - 确认加购并 pop 返回
 */
export class ProductDetailController {
  private vm: ProductDetailViewModel

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

  /**
   * 加购：vm.addCount +1，并通过 setPopParam 同步给上一页的 onResult 回调。
   */
  addToCart(): void {
    this.vm.addCount++
    HMRouterMgr.setPopParam(this.vm.addCount)
  }

  /**
   * 减购：vm.addCount -1（最小为 0），并同步 setPopParam。
   */
  decreaseCart(): void {
    if (this.vm.addCount > 0) {
      this.vm.addCount--
      HMRouterMgr.setPopParam(this.vm.addCount)
    }
  }

  /**
   * 确认加购并 pop 回上一页。
   * 数量已在 addToCart/decreaseCart 中通过 setPopParam 设置好，直接 pop 即可。
   */
  confirmAndBack(): void {
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
