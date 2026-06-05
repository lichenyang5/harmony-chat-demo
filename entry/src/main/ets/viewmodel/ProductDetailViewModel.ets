import { Product } from '../models/productModel'

/**
 * 商品详情页视图状态。
 *
 * 将原本分散在 ProductDetailPage @Local 字段集中到此处，
 * 由 ProductDetailController 统一读写，UI 层只负责渲染。
 */
@ObservedV2
export class ProductDetailViewModel {
  /** 当前展示的商品，由路由参数注入（aboutToAppear 时初始化）*/
  @Trace product: Product = new Product()

  /** 当前加购数量，+/- 按钮修改，随 setPopParam 实时同步给上一页 */
  @Trace addCount: number = 0

  /** 页面生命周期日志，演示 addObserver API，最多保留 5 条 */
  @Trace lifecycleLog: string[] = []
}
