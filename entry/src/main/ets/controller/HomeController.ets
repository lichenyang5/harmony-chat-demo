import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { Product } from '../models/productModel'
import { HomeViewModel } from '../viewmodel/HomeViewModel'
import { ProductBiz } from '../biz/ProductBiz'
import {
  distributeWaterfall,
  matchesWaterfallSearch,
  WaterfallColumns
} from '../utils/WaterfallLayout'

/**
 * 首页控制器。
 *
 * 职责：
 * - 进入首页时调 /api/products 拉内容列表
 * - 跳转到商品详情页（push + param）
 * - 搜索后按卡片预估高度重新分配到当前更短的一列
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
      this.rebuildWaterfall()
      if (list.length === 0) {
        this.vm.error = '暂无推荐内容'
      }
    } catch (e) {
      this.vm.error = '加载失败，请点击重试'
    } finally {
      this.vm.loading = false
    }
  }

  /** 搜索输入变化后立即过滤，并基于过滤结果重新计算两列。 */
  updateSearchKeyword(keyword: string): void {
    this.vm.searchKeyword = keyword
    this.rebuildWaterfall()
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
  private getFilteredProducts(): Product[] {
    return this.vm.products.filter((product: Product) => {
      return matchesWaterfallSearch(product, this.vm.searchKeyword)
    })
  }

  /**
   * 按预估卡片总高度分列，而不是按下标奇偶交替。
   * 预估会同时考虑封面、标题和摘要的可见行数。
   */
  private rebuildWaterfall(): void {
    const columns: WaterfallColumns<Product> = distributeWaterfall(this.getFilteredProducts())
    this.vm.leftProducts = columns.left
    this.vm.rightProducts = columns.right
  }
}
