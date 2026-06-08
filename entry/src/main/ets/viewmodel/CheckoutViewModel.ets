import { Order } from '../models/orderModel'

/**
 * 结算页视图状态。
 *
 * 设计取舍：order 默认 new Order() 而不是 undefined，
 * 避免在 build 里到处 if (this.vm.order) 守护；
 * 用单独的 hasOrder 标志区分"购物车空"和"已生成订单"。
 */
@ObservedV2
export class CheckoutViewModel {
  /** 当前待支付订单（aboutToAppear 时由 controller 从购物车生成） */
  @Trace order: Order = new Order()

  /** 是否已成功生成订单（购物车为空时为 false，UI 显示空态） */
  @Trace hasOrder: boolean = false

  /** 是否正在支付（按钮转圈 + 禁用） */
  @Trace paying: boolean = false
}
