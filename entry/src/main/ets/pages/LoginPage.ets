import { HMRouter } from '@hadss/hmrouter'
import { AuthController } from '../controller/AuthController'
import { AuthViewModel } from '../viewmodel/AuthViewModel'
import { hasToken } from '../utils/AuthPersist'
import { HMUtil } from '../utils/HMUtil'
import { route } from '../constants/HMConstants'

@HMRouter({ pageUrl: route.PAGE_LOGIN })
@ComponentV2
export struct Login {
  @Local vm: AuthViewModel = new AuthViewModel()
  @Local controller: AuthController = new AuthController(this.vm)

  aboutToAppear(): void {
    if (hasToken()) {
      HMUtil.pop()   // ← 改成 pop（已登录回到上一页，不再 replace 到 Home）
    }
  }

  build() {
    Column({ space: 20 }) {
      Text('登录').fontSize(24)

      Row({ space: 12 }) {
        Text('账户')
        TextInput({ placeholder: '请输入账户', text: this.vm.userName })
          .onChange((val: string) => { this.vm.userName = val })
          .layoutWeight(1)
      }

      Row({ space: 12 }) {
        Text('密码')
        TextInput({ placeholder: '请输入密码', text: this.vm.password })
          .type(InputType.Password)
          .onChange((val: string) => { this.vm.password = val })
          .layoutWeight(1)
      }

      Button('登录')
        .width('100%')
        .onClick(() => { this.controller.login() })
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
