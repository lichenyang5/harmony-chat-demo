import { Product } from '../models/productModel'

/**
 * 我的收藏页视图状态。
 *
 * products 是"商品全表 ∩ favoriteIds"的过滤结果。
 * 进入页面时 controller 拉一次 /api/products，filter 出收藏的，写入此处。
 */
@ObservedV2
export class FavoriteListViewModel {
  @Trace products: Product[] = []
  @Trace loading: boolean = false
  @Trace error: string = ''
}
