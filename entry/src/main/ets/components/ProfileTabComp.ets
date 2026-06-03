import { HMRouterMgr } from '@hadss/hmrouter'
import { route, NAV_ID } from '../constants/HMConstants'
import { tabState } from '../viewmodel/AppTabState'
import { clearAuth, getAuthPersist } from '../utils/AuthPersist'

interface MenuItem {
  label: string
  action: () => void
}

@ComponentV2
export struct ProfileTabComp {
  private menuItems: MenuItem[] = [
    {
      label: '消息记录',
      action: () => {
        HMRouterMgr.push({ navigationId: NAV_ID, pageUrl: route.PAGE_CHAT_HISTORY })
      }
    },
    { label: '帮助与反馈', action: () => {} },
    { label: '关于', action: () => {} }
  ]

  private logout(): void {
    // 1. 重置 Tab 下标（AppStorageV2 全局状态）
    tabState.currentIndex = 0
    // 2. 清除持久化 token（PersistenceV2）
    clearAuth()
    // 3. replace 到登录页（不保留回退栈，用户无法返回首页）
    // HMRouterMgr.replace({ navigationId: NAV_ID, pageUrl: route.PAGE_LOGIN })
  }

  build() {
    Column() {

      // 用户信息区
      Column({ space: 10 }) {
        // 头像
        Text(getAuthPersist().userName ? getAuthPersist().userName.charAt(0).toUpperCase() : 'U')
          .width(72)
          .height(72)
          .fontSize(28)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .backgroundColor('#007DFF')
          .borderRadius(36)
          .margin({ top: 40 })

        // 用户名（从 PersistenceV2 读取）
        Text(getAuthPersist().userName || '用户')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        // 演示 AppStorageV2：当前 Tab 下标
        Text(`AppStorageV2 · currentIndex = ${tabState.currentIndex}`)
          .fontSize(11)
          .fontColor('#AAAAAA')
          .margin({ bottom: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 20 })
      .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
      .backgroundColor(Color.White)

      // 通用菜单
      Column() {
        ForEach(this.menuItems, (item: MenuItem) => {
          Row() {
            Text(item.label).fontSize(15)
            Blank()
            Text('>').fontColor('#CCCCCC').fontSize(14)
          }
          .width('100%')
          .height(52)
          .padding({ left: 20, right: 20 })
          .border({ width: { bottom: 0.5 }, color: '#F5F5F5' })
          .backgroundColor(Color.White)
          .onClick(() => { item.action() })
        })
      }
      .margin({ top: 12 })

      Blank()

      // 退出登录 / 去登录
      if (getAuthPersist().token.length > 0) {
        Button('退出登录')
          .width('90%')
          .height(48)
          .backgroundColor('#FFF1F0')
          .fontColor('#FF4D4F')
          .border({ width: 1, color: '#FFCCC7' })
          .margin({ bottom: 40 })
          .onClick(() => { this.logout() })
      } else {
        Button('去登录')
          .width('90%')
          .height(48)
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .margin({ bottom: 40 })
          .onClick(() => {
            HMRouterMgr.push({ navigationId: NAV_ID, pageUrl: route.PAGE_LOGIN })
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }
}
