import { tabState } from '../viewmodel/AppTabState'
import { AuthPersist } from '../utils/AuthPersist'
import { ThemeState } from '../viewmodel/ThemeState'
import { ProfileController } from '../controller/ProfileController'
import { FavoriteState, getFavoriteState } from '../viewmodel/FavoriteState'
import { getOrderState, OrderState } from '../viewmodel/OrderState'

/**
 * 我的 Tab 组件。
 *
 * 职责：纯 UI 渲染（头像、用户名、菜单列表、主题切换、退出登录按钮）。
 * 登出逻辑和导航跳转委托给 ProfileController。
 *
 * ─── 角标响应式（关键经验） ──────────────────────────────────────────
 * "我的订单 / 我的收藏" 角标必须**完全内联在 build 里**，直接读
 * `this.orderState.unpaidCount` / `this.favorite.totalCount`。
 *
 * 试过的失败方式：
 *   ❌ 通过 @Builder 参数把 number 传进去 —— 参数 evaluation 后 V2
 *      就丢了依赖（@Builder 是另一个 render scope）
 *   ❌ @Monitor 监听 + 本地 @Local number 字段 —— 本次 ArkUI 版本下
 *      回调触发但 UI 没刷
 *
 * 成功参照：[HomeTabComp](../components/HomeTabComp.ets) 的购物车角标 ——
 * 直接 `if (this.cart.totalCount > 0) Text(...)` 内联在 build 里，
 * V2 自动建立依赖，cart 变化时角标实时更新。本组件照搬同一套写法。
 */
@ComponentV2
export struct ProfileTabComp {
  /** 来自父组件（HomePage）的登录凭证 */
  @Consumer() auth: AuthPersist = new AuthPersist()
  /** 来自父组件（HomePage）的全局主题 */
  @Consumer() theme: ThemeState = new ThemeState()

  /** 全局收藏单例 —— 驱动"我的收藏"角标 */
  @Local favorite: FavoriteState = getFavoriteState()
  /** 全局订单单例 —— 驱动"我的订单"待支付角标 */
  @Local orderState: OrderState = getOrderState()

  private controller: ProfileController = new ProfileController()

  // ─── @Builder ─────────────────────────────────────────────────────────────

  /** 主题切换按钮 */
  @Builder
  themeSwitchButton() {
    Button(this.theme.isDark ? '白天模式' : '夜间模式')
      .width('90%')
      .height(44)
      .backgroundColor(this.theme.secondaryButtonBg)
      .fontColor(this.theme.secondaryButtonText)
      .margin({ top: 20, bottom: 12 })
      .onClick(() => {
        this.theme.isDark = !this.theme.isDark
      })
  }

  /**
   * 无角标的菜单行（帮助 / 关于）。
   * 这类菜单没有响应式依赖，安心用 @Builder 收敛代码。
   */
  @Builder
  plainMenuRow(label: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.theme.textPrimary)

      Blank()

      Text('>')
        .fontColor(this.theme.textTertiary)
        .fontSize(14)
    }
    .width('100%')
    .height(52)
    .padding({ left: 20, right: 20 })
    .border({ width: { bottom: 0.5 }, color: this.theme.divider })
    .backgroundColor(this.theme.surface)
    .onClick(() => { action() })
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Column() {
      // ── 用户信息区 ────────────────────────────────────────────────────
      Column({ space: 10 }) {
        Text(this.auth.userName ? this.auth.userName.charAt(0).toUpperCase() : 'U')
          .width(72)
          .height(72)
          .fontSize(28)
          .fontColor(this.theme.onPrimary)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.theme.primary)
          .borderRadius(36)
          .margin({ top: 40 })

        Text(this.auth.userName || '用户')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Text(`AppStorageV2 · currentIndex = ${tabState.currentIndex}`)
          .fontSize(11)
          .fontColor(this.theme.textTertiary)
          .margin({ bottom: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 20 })
      .border({ width: { bottom: 0.5 }, color: this.theme.border })
      .backgroundColor(this.theme.surface)

      // ── 菜单列表 ──────────────────────────────────────────────────────
      Column() {
        // ─ 我的订单（内联，照搬 [HomeTabComp] 购物车角标模式）─
        Row() {
          Text('我的订单')
            .fontSize(15)
            .fontColor(this.theme.textPrimary)

          Blank()

          // 直接在 build 顶层访问 getter，V2 自动建立依赖
          if (this.orderState.unpaidCount > 0) {
            Text(`${this.orderState.unpaidCount}`)
              .fontSize(11)
              .fontColor(this.theme.onDanger)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(this.theme.danger)
              .borderRadius(8)
              .margin({ right: 8 })
          }

          Text('>')
            .fontColor(this.theme.textTertiary)
            .fontSize(14)
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 20 })
        .border({ width: { bottom: 0.5 }, color: this.theme.divider })
        .backgroundColor(this.theme.surface)
        .onClick(() => this.controller.goOrderList())

        // ─ 我的收藏（内联，照搬 [HomeTabComp] 购物车角标模式）─
        Row() {
          Text('我的收藏')
            .fontSize(15)
            .fontColor(this.theme.textPrimary)

          Blank()

          if (this.favorite.totalCount > 0) {
            Text(`${this.favorite.totalCount}`)
              .fontSize(11)
              .fontColor(this.theme.onDanger)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(this.theme.danger)
              .borderRadius(8)
              .margin({ right: 8 })
          }

          Text('>')
            .fontColor(this.theme.textTertiary)
            .fontSize(14)
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 20 })
        .border({ width: { bottom: 0.5 }, color: this.theme.divider })
        .backgroundColor(this.theme.surface)
        .onClick(() => this.controller.goFavoriteList())

        // ─ 其余无角标菜单 ─
        this.plainMenuRow('帮助与反馈', () => {})
        this.plainMenuRow('关于', () => {})
      }
      .margin({ top: 12 })

      Blank()

      this.themeSwitchButton()

      // ── 退出登录 / 去登录 ────────────────────────────────────────────
      if (this.auth.token.length > 0) {
        Button('退出登录')
          .width('90%')
          .height(48)
          .backgroundColor(this.theme.dangerBg)
          .fontColor(this.theme.danger)
          .border({ width: 1, color: this.theme.dangerBorder })
          .margin({ bottom: 40 })
          .onClick(() => { this.controller.logout() })
      } else {
        Button('去登录')
          .width('90%')
          .height(48)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.onPrimary)
          .margin({ bottom: 40 })
          .onClick(() => { this.controller.goLogin() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
