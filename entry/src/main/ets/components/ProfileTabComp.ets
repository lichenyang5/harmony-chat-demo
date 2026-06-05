import { tabState } from '../viewmodel/AppTabState'
import { AuthPersist } from '../utils/AuthPersist'
import { ThemeState } from '../viewmodel/ThemeState'
import { ProfileController } from '../controller/ProfileController'

/** 菜单项数据结构：显示文字 + 点击动作 */
interface MenuItem {
  label: string
  action: () => void
}

/**
 * 我的 Tab 组件。
 *
 * 职责：纯 UI 渲染（头像、用户名、菜单列表、主题切换、退出登录按钮）。
 * 登出逻辑和导航跳转委托给 ProfileController。
 */
@ComponentV2
export struct ProfileTabComp {
  /** 来自父组件（HomePage）的登录凭证，用于展示头像首字母和用户名 */
  @Consumer() auth: AuthPersist = new AuthPersist()
  /** 来自父组件（HomePage）的全局主题，用于动态颜色和切换 */
  @Consumer() theme: ThemeState = new ThemeState()

  private controller: ProfileController = new ProfileController()

  /**
   * 菜单项列表（数据 + 动作绑定）。
   * 动作指向 controller 方法，组件本身不含业务逻辑。
   */
  private menuItems: MenuItem[] = [
    {
      label: '消息记录',
      action: () => this.controller.goHistory()
    },
    {
      label: '帮助与反馈',
      action: () => {}
    },
    {
      label: '关于',
      action: () => {}
    }
  ]

  // ─── @Builder ─────────────────────────────────────────────────────────────

  /** 主题切换按钮（亮色/暗黑互切） */
  @Builder
  themeSwitchButton() {
    Button(this.theme.isDark ? '白天模式' : '夜间模式')
      .width('90%')
      .height(44)
      .backgroundColor(this.theme.secondaryButtonBg)
      .fontColor(this.theme.secondaryButtonText)
      .margin({ top: 20, bottom: 12 })
      .onClick(() => {
        // isDark 是 @Trace 字段，修改后全局所有组件自动重渲染
        this.theme.isDark = !this.theme.isDark
      })
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Column() {
      // ── 用户信息区（头像 + 用户名 + debug 信息）──────────────────────
      Column({ space: 10 }) {
        // 头像：取用户名首字母大写，未登录显示 U
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

        // 演示 AppStorageV2：实时显示当前 Tab 下标
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

      // ── 通用菜单列表 ────────────────────────────────────────────────
      Column() {
        ForEach(this.menuItems, (item: MenuItem) => {
          Row() {
            Text(item.label)
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
          .onClick(() => {
            item.action()
          })
        })
      }
      .margin({ top: 12 })

      Blank()

      this.themeSwitchButton()

      // ── 退出登录 / 去登录 ────────────────────────────────────────────
      if (this.auth.token.length > 0) {
        // 已登录：显示退出登录按钮
        Button('退出登录')
          .width('90%')
          .height(48)
          .backgroundColor(this.theme.dangerBg)
          .fontColor(this.theme.danger)
          .border({ width: 1, color: this.theme.dangerBorder })
          .margin({ bottom: 40 })
          .onClick(() => {
            this.controller.logout()
          })
      } else {
        // 未登录：显示去登录按钮
        Button('去登录')
          .width('90%')
          .height(48)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.onPrimary)
          .margin({ bottom: 40 })
          .onClick(() => {
            this.controller.goLogin()
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
