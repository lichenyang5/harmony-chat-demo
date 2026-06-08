import { PersistenceV2 } from '@kit.ArkUI'

/**
 * 全局收藏状态。
 *
 * 设计：
 * - 只存 productId（string[]），不存整个 Product —— 商品详情可随时从
 *   接口/缓存还原，列表里也只用 id 高亮心形。
 * - PersistenceV2 持久化到本地，App 重启后状态自动恢复。
 *
 * V2 响应式要点：
 * - favoriteIds 是 @Trace 字段，但**数组**的 push / splice 等原地修改
 *   不会触发 V2 重渲染，必须**整体替换**新数组才行（参考 CartState 写法）。
 *
 * 使用：
 * ```ts
 * const fav = getFavoriteState()
 * fav.toggle(productId)   // 加入或取消收藏
 * fav.has(productId)      // 是否已收藏（驱动心形空心/实心）
 * fav.totalCount          // 收藏数量（个人中心红点用）
 * fav.favoriteIds         // 全列表（"我的收藏"页 ForEach 数据源）
 * ```
 */
@ObservedV2
export class FavoriteState {
  /** 收藏的商品 id 数组 */
  @Trace favoriteIds: string[] = []

  /** 收藏总数 */
  get totalCount(): number {
    return this.favoriteIds.length
  }

  /** 是否已收藏 */
  has(id: string): boolean {
    return this.favoriteIds.indexOf(id) >= 0
  }

  /** 切换收藏状态（整体替换数组，触发 V2 响应） */
  toggle(id: string): void {
    if (this.has(id)) {
      this.favoriteIds = this.favoriteIds.filter((x) => x !== id)
    } else {
      const next = this.favoriteIds.slice()
      next.push(id)
      this.favoriteIds = next
    }
  }

  /** 清空收藏 */
  clear(): void {
    this.favoriteIds = []
  }
}

/**
 * 获取全局收藏单例。
 * PersistenceV2.connect 用 key 'FavoriteState' 持久化到本地存储；
 * 任何地方调用都拿到同一个实例，关 App 重启后状态自动恢复。
 */
export function getFavoriteState(): FavoriteState {
  return PersistenceV2.connect(FavoriteState, 'FavoriteState', () => new FavoriteState())!
}
