import { AuthBiz } from '../biz/AuthBiz'
import { LoginRequest } from '../models/userModel'
import { AuthViewModel } from '../viewmodel/AuthViewModel'
import { HMUtil } from '../utils/HMUtil'
import { saveAuth } from '../utils/AuthPersist'
import { route } from '../constants/HMConstants'

export class AuthController {
  private biz: AuthBiz = new AuthBiz()
  private vm: AuthViewModel

  constructor(vm: AuthViewModel) {
    this.vm = vm
  }

  login(): void {
    if (!this.vm.userName || !this.vm.password) {
      return
    }

    const params: LoginRequest = {
      userName: this.vm.userName,
      password: this.vm.password
    }

    this.vm.isLoading = true

    this.biz.login(params)
      .then((result) => {
        this.vm.isLoading = false
        if (!result) {
          return
        }
        this.vm.userInfo = result
        this.vm.isLogin = true
        this.vm.password = ''
        saveAuth(result.token, result.userName, result.userId)
        HMUtil.pop() // ← 改成 pop（已登录回到上一页，不再 replace 到 Home）
      })
      .catch(() => {
        this.vm.isLoading = false
      })
  }
}
