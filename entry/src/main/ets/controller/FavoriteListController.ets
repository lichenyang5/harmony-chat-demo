import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { Product } from '../models/productModel'
import { ProductBiz } from '../biz/ProductBiz'
import { FavoriteState, getFavoriteState } from '../viewmodel/FavoriteState'
import { FavoriteListViewModel } from '../viewmodel/FavoriteListViewModel'

/**
 * 我的收藏页控制器。
 *
 * 数据获取策略：FavoriteState 只存 productId，无法直接还原 Product；
 * 进页面时调一次 /api/products 拿全表，按 favoriteIds 过滤。
 *
 * 这样做的好处：商品价格/库存等变更后，收藏页看到的是最新数据。
 */
export class FavoriteListController {
  private vm: FavoriteListViewModel
  private biz: ProductBiz = new ProductBiz()
  private favorite: FavoriteState = getFavoriteState()

  constructor(vm: FavoriteListViewModel) {
    this.vm = vm
  }

  /** 进入页面时调用：拉商品并按收藏 id 过滤 */
  async loadAndFilter(): Promise<void> {
    this.vm.loading = true
    this.vm.error = ''
    try {
      const all = await this.biz.list()
      this.vm.products = all.filter((p) => this.favorite.has(p.id))
    } catch (e) {
      this.vm.error = '加载失败，请重试'
    } finally {
      this.vm.loading = false
    }
  }

  /** 点商品卡片：跳商品详情 */
  goDetail(product: Product): void {
    HMRouterMgr.push({
      navigationId: NAV_ID,
      pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL,
      param: product
    })
  }
}
