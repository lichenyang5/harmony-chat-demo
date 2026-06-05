/**
 * 首页视图状态。
 *
 * 当前仅管理购物车计数；后续可扩展搜索关键词、刷新状态等字段。
 */
@ObservedV2
export class HomeViewModel {
  /** 购物车累计数量，由 ProductDetailPage pop 时的 onResult 回调累加 */
  @Trace cartCount: number = 0
}
