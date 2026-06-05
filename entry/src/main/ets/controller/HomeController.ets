import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { MOCK_PRODUCTS, Product } from '../models/productModel'
import { HomeViewModel } from '../viewmodel/HomeViewModel'

/**
 * 首页控制器。
 *
 * 职责：
 * - 跳转到商品详情页（push + param）
 * - 根据搜索关键词过滤商品列表
 *
 * 注：详情页加购后不再通过 onResult 回调累加，
 * 改为详情页直接写入全局 CartState（getCartState().addN(...)），
 * 首页购物车角标通过 CartState.totalCount 自动同步。
 */
export class HomeController {
  private vm: HomeViewModel

  constructor(vm: HomeViewModel) {
    this.vm = vm
  }

  /**
   * 跳转到商品详情页，携带 product 作为路由参数。
   * 不需要 onResult 回调，全局 CartState 接管加购同步。
   */
  goDetail(product: Product): void {
    HMRouterMgr.push({
      navigationId: NAV_ID,
      pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL,
      param: product
    })
  }

  /**
   * 按搜索关键词过滤商品列表（name 或 desc 包含关键词即匹配）。
   * V2 响应式：build 内访问 vm.searchKeyword 自动建立依赖。
   */
  getFilteredProducts(): Product[] {
    const kw = this.vm.searchKeyword.trim()
    if (!kw) {
      return MOCK_PRODUCTS
    }
    return MOCK_PRODUCTS.filter((p) => p.name.includes(kw) || p.desc.includes(kw))
  }
}
