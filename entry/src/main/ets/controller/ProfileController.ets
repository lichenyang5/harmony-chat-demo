import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { EntryRoutes } from '../constants/EntryRoutes'
import { tabState } from '../viewmodel/AppTabState'
import { clearAuth } from '../utils/AuthPersist'

/**
 * 我的页面控制器。
 *
 * 职责：
 * - 退出登录（重置 Tab 下标 + 清除持久化凭证）
 * - 跳转到登录页（未登录时"去登录"按钮）
 */
export class ProfileController {
  /**
   * 退出登录。
   *
   * 1. 重置 AppStorageV2 中的 Tab 下标为 0（首页）
   * 2. 清除 PersistenceV2 中的 token / userName / userId
   * 3. 不主动跳转，留在当前页面；auth.token 变为空后，
   *    ProfileTabComp 会响应式切换为"去登录"按钮
   */
  logout(): void {
    tabState.currentIndex = 0
    clearAuth()
  }

  /**
   * 跳转到登录页（用于未登录状态下的"去登录"入口）。
   */
  goLogin(): void {
    HMRouterMgr.push({
      navigationId: NAV_ID,
      pageUrl: EntryRoutes.PAGE_LOGIN
    })
  }

  /** 跳转到我的订单页（受 AuthInterceptor 保护） */
  goOrderList(): void {
    HMRouterMgr.push({
      navigationId: NAV_ID,
      pageUrl: EntryRoutes.PAGE_ORDER_LIST
    })
  }

  /** 跳转到我的收藏页（不需要登录） */
  goFavoriteList(): void {
    HMRouterMgr.push({
      navigationId: NAV_ID,
      pageUrl: EntryRoutes.PAGE_FAVORITE_LIST
    })
  }
}
