import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { route } from '../constants/HMConstants'

@HMRouter({ pageUrl: route.DIALOG_LOGIN_PROMPT, dialog: true })
@ComponentV2
export struct LoginPromptDialog {

  build() {
    Column() {
      Column() {
        Text('请先登录')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 20, bottom: 8 })

        Text('该功能需要登录后才能使用')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 20 })

        Row() {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor('#F5F5F5')
            .fontColor('#333333')
            .onClick(() => {
              HMRouterMgr.pop()   // 关掉 dialog
            })

          Button('去登录')
            .layoutWeight(1)
            .margin({ left: 12 })
            .onClick(() => {
              HMRouterMgr.pop()   // 先关 dialog
              HMRouterMgr.push({ pageUrl: route.PAGE_LOGIN })  // 再去登录页
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .width('80%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#80000000')   // 半透明遮罩
  }
}