import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { Product } from '../models/productModel'
import { HomeViewModel } from '../viewmodel/HomeViewModel'
import { ProductBiz } from '../biz/ProductBiz'

/**
 * 首页控制器。
 *
 * 职责：
 * - 进入首页时调 /api/products 拉商品列表
 * - 跳转到商品详情页（push + param）
 * - 根据搜索关键词在已拉取的 vm.products 上做内存过滤
 *
 * 注：详情页加购后不通过 onResult 回调累加，
 * 改为详情页直接写入全局 CartState（getCartState().addN(...)），
 * 首页购物车角标通过 CartState.totalCount 自动同步。
 */
export class HomeController {
  private vm: HomeViewModel
  private biz: ProductBiz = new ProductBiz()

  constructor(vm: HomeViewModel) {
    this.vm = vm
  }

  /**
   * 拉商品列表：进首页时调一次，错误时给出可重试提示。
   * 通过 @Trace 字段把 loading / error / products 暴露给 UI 自动渲染。
   */
  async loadProducts(): Promise<void> {
    this.vm.loading = true
    this.vm.error = ''
    try {
      const list = await this.biz.list()
      this.vm.products = list
      if (list.length === 0) {
        this.vm.error = '暂无商品'
      }
    } catch (e) {
      this.vm.error = '加载失败，请下拉重试'
    } finally {
      this.vm.loading = false
    }
  }

  /** 跳转到商品详情页，携带 product 作为路由参数 */
  goDetail(product: Product): void {
    HMRouterMgr.push({
      navigationId: NAV_ID,
      pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL,
      param: product
    })
  }

  /**
   * 按搜索关键词过滤已拉取的商品列表。
   * V2 响应式：build 内访问 vm.searchKeyword / vm.products 自动建立依赖。
   */
  getFilteredProducts(): Product[] {
    const kw = this.vm.searchKeyword.trim()
    if (!kw) {
      return this.vm.products
    }
    return this.vm.products.filter((p) => p.name.includes(kw) || p.desc.includes(kw))
  }
}
