import { Product } from '../models/productModel'

/**
 * 首页视图状态。
 *
 * 字段：
 * - searchKeyword：搜索关键词（驱动内容过滤与重新分列）
 * - products：完整内容列表（aboutToAppear 时由 controller.loadProducts 拉取）
 * - leftProducts / rightProducts：按预估高度均衡后的两列数据
 * - loading：是否正在拉取，UI 显示骨架/加载提示
 * - error：拉取失败的提示文案，空字符串表示无错误
 *
 * 购物车计数已迁移到全局 CartState（viewmodel/CartState.ets），
 * 首页角标直接读 getCartState().totalCount，此处不冗余存储。
 */
@ObservedV2
export class HomeViewModel {
  /** 搜索关键词，绑定到顶部 Search 组件 */
  @Trace searchKeyword: string = ''

  /** 商品列表（从 /api/products 拉取） */
  @Trace products: Product[] = []

  /** 高度均衡后分配到左列的内容 */
  @Trace leftProducts: Product[] = []

  /** 高度均衡后分配到右列的内容 */
  @Trace rightProducts: Product[] = []

  /** 是否正在加载 */
  @Trace loading: boolean = false

  /** 加载错误文案（空表示无错） */
  @Trace error: string = ''
}
