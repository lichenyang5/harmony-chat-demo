import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { AuthController } from '../controller/AuthController'
import { AuthViewModel } from '../viewmodel/AuthViewModel'
import { hasToken } from '../utils/AuthPersist'
import { HMUtil } from 'common'
import { ThemeState, getThemeState } from '../viewmodel/ThemeState'

@HMRouter({ pageUrl: EntryRoutes.PAGE_LOGIN })
@ComponentV2
export struct Login {
  @Local vm: AuthViewModel = new AuthViewModel()
  @Local controller: AuthController = new AuthController(this.vm)
  @Local theme: ThemeState = getThemeState()

  aboutToAppear(): void {
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