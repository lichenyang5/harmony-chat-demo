/**
 * 首页视图状态。
 *
 * 当前仅管理搜索关键词。
 * 购物车计数已迁移到全局 CartState（参见 viewmodel/CartState.ets），
 * 首页角标直接读 getCartState().totalCount，无需在此处冗余存储。
 */
@ObservedV2
export class HomeViewModel {
  /** 搜索关键词，绑定到顶部 Search 组件，驱动 Grid 过滤 */
  @Trace searchKeyword: string = ''
}
