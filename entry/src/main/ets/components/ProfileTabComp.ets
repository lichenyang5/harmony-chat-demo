import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouterMgr } from '@hadss/hmrouter'
import { NAV_ID } from 'common'
import { tabState } from '../viewmodel/AppTabState'
import { clearAuth, AuthPersist } from '../utils/AuthPersist'
import { ThemeState } from '../viewmodel/ThemeState'

interface MenuItem {
  label: string
  action: () => void
}

@ComponentV2
export struct ProfileTabComp {
  @Consumer() auth: AuthPersist = new AuthPersist()
  @Consumer() theme: ThemeState = new ThemeState()

  private menuItems: MenuItem[] = [
    {
      label: '消息记录',
      action: () => {
        HMRouterMgr.push({
          navigationId: NAV_ID,
          pageUrl: EntryRoutes.PAGE_CHAT_HISTORY
        })
      }
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

  private logout(): void {
    // 1. 重置 Tab 下标
    tabState.currentIndex = 0

    // 2. 清除持久化 token
    clearAuth()

    // 3. 当前逻辑是留在首页，通过 auth 状态切换成“去登录”
    // HMRouterMgr.replace({ navigationId: NAV_ID, pageUrl: EntryRoutes.PAGE_LOGIN })
  }

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

  build() {
    Column() {
      // 用户信息区
      Column({ space: 10 }) {
        // 头像
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

        // 用户名
        Text(this.auth.userName || '用户')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        // 演示 AppStorageV2：当前 Tab 下标
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

      // 通用菜单
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

      // 退出登录 / 去登录
      if (this.auth.token.length > 0) {
        Button('退出登录')
          .width('90%')
          .height(48)
          .backgroundColor(this.theme.dangerBg)
          .fontColor(this.theme.danger)
          .border({ width: 1, color: this.theme.dangerBorder })
          .margin({ bottom: 40 })
          .onClick(() => {
            this.logout()
          })
      } else {
        Button('去登录')
          .width('90%')
          .height(48)
          .backgroundColor(this.theme.primary)
          .fontColor(this.theme.onPrimary)
          .margin({ bottom: 40 })
          .onClick(() => {
            HMRouterMgr.push({
              navigationId: NAV_ID,
              pageUrl: EntryRoutes.PAGE_LOGIN
            })
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}