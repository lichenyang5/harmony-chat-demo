import { HMRouterMgr, HMPopInfo } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { MOCK_PRODUCTS, Product } from '../models/productModel'
import { HomeViewModel } from '../viewmodel/HomeViewModel'

/**
 * 首页控制器。
 *
 * 职责：
 * - 跳转到商品详情页（push + param）
 * - 接收详情页 pop 时返回的加购数量，累加到 vm.cartCount
 */
export class HomeController {
  private vm: HomeViewModel

  constructor(vm: HomeViewModel) {
    this.vm = vm
  }

  /**
   * 跳转到商品详情页并注册返回结果回调。
   *
   * push 时携带 product 作为路由参数；详情页调用 setPopParam(count) 后 pop，
   * onResult 在当前页面收到 addCount，若大于 0 则累加到购物车。
   *
   * @param product 要展示的商品
   */
  goDetail(product: Product): void {
    HMRouterMgr.push(
      {
        navigationId: NAV_ID,
        pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL,
        param: product
      },
      {
        onResult: (popInfo: HMPopInfo) => {
          const addCount = popInfo.result as number
          if (addCount > 0) {
            this.vm.cartCount += addCount
          }
        }
      }
    )
  }
  //   搜索筛选
  getFilteredProducts(): Product[] {
    const kw = this.vm.searchKeyword.trim()
    if (!kw) return MOCK_PRODUCTS
    return MOCK_PRODUCTS.filter(p =>
    p.name.includes(kw) || p.desc.includes(kw)
    )
  }
}

