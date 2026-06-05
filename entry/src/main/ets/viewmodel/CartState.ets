import { PersistenceV2, Type } from '@kit.ArkUI'
import { Product } from '../models/productModel'

/**
 * 购物车展示用聚合项（实时计算，不持久化）。
 */
export interface GroupedCartItem {
  product: Product
  count: number
}

/**
 * 全局购物车状态。
 *
 * 设计哲学：
 * - items 是 Product[]，加购就 push，**不做去重**（业务代码最简）
 * - 同一商品加 N 次就在数组里出现 N 次
 * - 角标 totalCount 直接用数组长度
 * - 购物车页展示时按 productId 聚合（getGrouped）合并显示
 *
 * 持久化：PersistenceV2 + @Type(Product) ——
 * @Type 装饰器告诉框架 items 数组里装的是 Product 类实例，
 * 反序列化时还原成 Product，否则会变成普通对象丢失类型信息。
 *
 * 使用：
 * ```ts
 * const cart = getCartState()
 * cart.add(product)             // 加购一件
 * cart.addN(product, 3)         // 加购 3 件（详情页用）
 * cart.removeOne(productId)     // - 按钮减一件
 * cart.remove(productId)        // 左滑删除（删所有相同 id）
 * cart.totalCount               // 角标数字
 * cart.getGrouped()             // 购物车页 ForEach 数据源
 * ```
 */
@ObservedV2
export class CartState {
  /**
   * 购物车原始数组（重复 push 不去重）。
   * @Type(Product) 装饰器告诉 PersistenceV2 反序列化时还原为 Product 实例。
   */
  @Trace @Type(Product) items: Product[] = []

  /** 总件数 = 数组长度（不去重，每次 push 都计 1 件） */
  get totalCount(): number {
    return this.items.length
  }

  /** 合计金额 */
  get totalAmount(): number {
    return this.items.reduce((sum, p) => sum + p.price, 0)
  }

  /** 加购一件（最常用） */
  add(p: Product): void {
    this.items.push(p)
  }

  /** 加购 N 件（详情页确认加购时按选定数量批量 push） */
  addN(p: Product, count: number): void {
    for (let i = 0; i < count; i++) {
      this.items.push(p)
    }
  }

  /** 减一件：移除第一个匹配项（购物车页 - 按钮） */
  removeOne(productId: string): void {
    const idx = this.items.findIndex((p) => p.id === productId)
    if (idx >= 0) {
      const next = this.items.slice()
      next.splice(idx, 1)
      this.items = next   // 整体赋值新数组，确保 V2 触发响应
    }
  }

  /** 删除：移除所有相同 productId 的项（左滑删除按钮） */
  remove(productId: string): void {
    this.items = this.items.filter((p) => p.id !== productId)
  }

  /** 清空购物车 */
  clear(): void {
    this.items = []
  }

  /**
   * 展示用聚合：把重复的同 id 商品合并成 { product, count }。
   * 实时计算（无缓存），购物车页 ForEach 用这个数据源。
   */
  getGrouped(): GroupedCartItem[] {
    const map = new Map<string, GroupedCartItem>()
    for (const p of this.items) {
      const entry = map.get(p.id)
      if (entry) {
        entry.count++
      } else {
        map.set(p.id, { product: p, count: 1 })
      }
    }
    return Array.from(map.values())
  }
}

/**
 * 获取全局购物车单例。
 * PersistenceV2.connect 用 key 'CartState' 持久化到本地存储；
 * 任何地方调用都拿到同一个实例，关 App 重启后状态自动恢复。
 */
export function getCartState(): CartState {
  return PersistenceV2.connect(CartState, 'CartState', () => new CartState())!
}
