import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'

import { login } from '../api/AuthApi'
import { LoginRequest } from '../models/AuthModel'
import { RouteConstants } from '../constants/RouteConstants'
import { AuthStorage } from '../utils/AuthStorage'
import { globalAuthStore } from '../stores/AuthStore'

@HMRouter({ pageUrl: RouteConstants.LOGIN })
@ComponentV2
export struct Login {
  @Local username: string = 'admin'
  @Local password: string = '123456'
  @Local isLoading: boolean = false
  @Local errorMessage: string = ''

  async handleLogin(): Promise<void> {
    const username = this.username.trim()
    const password = this.password.trim()

    if (!username || !password) {
      this.errorMessage = '请输入账号和密码'
      return
    }

    if (this.isLoading) {
      return
    }

    this.isLoading = true
    this.errorMessage = ''

    try {
      const requestParams: LoginRequest = {
        username: username,
        password: password
      }

      const res = await login(requestParams)

      if (res.code !== 0) {
        this.errorMessage = res.message || '登录失败'
        return
      }

      const context = getContext(this) as common.UIAbilityContext

      await AuthStorage.saveAuthCache(
        context,
        res.data.token,
        res.data.userInfo
      )

      globalAuthStore.setAuth(res.data.token, res.data.userInfo)

      HMRouterMgr.replace({
        pageUrl: RouteConstants.SETTING
      })
    } catch (error) {
      console.error(`login error: ${JSON.stringify(error)}`)
      this.errorMessage = '登录请求失败，请检查后端服务是否启动'
    } finally {
      this.isLoading = false
    }
  }

  build() {
    Column() {
      Text('登录')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#222222')
        .margin({ bottom: 8 })

      Text('鸿蒙聊天 Demo')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 36 })

      Column() {
        TextInput({
          placeholder: '请输入账号',
          text: this.username
        })
          .height(46)
          .width('100%')
          .backgroundColor('#F5F6F7')
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .enabled(!this.isLoading)
          .onChange((value: string) => {
            this.username = value
          })

        TextInput({
          placeholder: '请输入密码',
          text: this.password
        })
          .height(46)
          .width('100%')
          .type(InputType.Password)
          .backgroundColor('#F5F6F7')
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .margin({ top: 14 })
          .enabled(!this.isLoading)
          .onChange((value: string) => {
            this.password = value
          })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#E5484D')
            .width('100%')
            .margin({ top: 12 })
        }

        Button(this.isLoading ? '登录中' : '登录')
          .width('100%')
          .height(46)
          .margin({ top: 24 })
          .enabled(!this.isLoading)
          .onClick(() => {
            this.handleLogin()
          })

        Text('测试账号：admin / 123456')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 16 })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor('#F5F6F7')
    .justifyContent(FlexAlign.Center)
  }
}