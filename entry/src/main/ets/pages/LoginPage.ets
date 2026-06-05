import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { AuthController } from '../controller/AuthController'
import { AuthViewModel } from '../viewmodel/AuthViewModel'
import { hasToken } from '../utils/AuthPersist'
import { HMUtil } from 'common'
import { ThemeState, getThemeState } from '../viewmodel/ThemeState'

/**
 * 登录页面。
 *
 * 职责：纯 UI 渲染（账户/密码输入框、登录按钮）。
 * 登录业务逻辑委托给 AuthController（表单校验 → AuthBiz → AuthImp → HttpUtil）。
 *
 * 若已持有 token（如从其他页面跳转过来），直接 pop 返回，不展示登录页。
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_LOGIN })
@ComponentV2
export struct Login {
  /** 登录表单视图状态（userName / password / isLoading / isLogin）*/
  @Local vm: AuthViewModel = new AuthViewModel()
  @Local controller: AuthController = new AuthController(this.vm)
  /** 全局主题（亮色/暗黑），用于动态颜色 */
  @Local theme: ThemeState = getThemeState()

  aboutToAppear(): void {
    // 已有 token 表示已登录，无需再次登录，直接返回
    if (hasToken()) {
      HMUtil.pop()
    }
  }

  build() {
    Column({ space: 20 }) {
      Text('登录')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)

      Row({ space: 12 }) {
        Text('账户')
          .width(48)
          .fontSize(15)
          .fontColor(this.theme.textPrimary)

        TextInput({
          placeholder: '请输入账户',
          text: this.vm.userName
        })
          .onChange((val: string) => {
            this.vm.userName = val
          })
          .layoutWeight(1)
          .height(44)
          .fontColor(this.theme.inputText)
          .placeholderColor(this.theme.placeholderText)
          .backgroundColor(this.theme.inputBg)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
      }

      Row({ space: 12 }) {
        Text('密码')
          .width(48)
          .fontSize(15)
          .fontColor(this.theme.textPrimary)

        TextInput({
          placeholder: '请输入密码',
          text: this.vm.password
        })
          .type(InputType.Password)
          .onChange((val: string) => {
            this.vm.password = val
          })
          .layoutWeight(1)
          .height(44)
          .fontColor(this.theme.inputText)
          .placeholderColor(this.theme.placeholderText)
          .backgroundColor(this.theme.inputBg)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
      }

      Button('登录')
        .width('100%')
        .height(48)
        .backgroundColor(
          this.vm.userName.trim().length > 0 && this.vm.password.trim().length > 0
            ? this.theme.primary
            : this.theme.disabledBg
        )
        .fontColor(this.theme.onPrimary)
        .enabled(this.vm.userName.trim().length > 0 && this.vm.password.trim().length > 0)
        .margin({ top: 8 })
        .onClick(() => {
          this.controller.login()
        })
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme.bg)
  }
}