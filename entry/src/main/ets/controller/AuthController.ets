import { AuthBiz } from '../biz/AuthBiz'
import { LoginRequest } from '../models/userModel'
import { AuthViewModel } from '../viewmodel/AuthViewModel'
import { HMUtil } from 'common'
import { saveAuth } from '../utils/AuthPersist'

/**
 * 认证控制器。
 *
 * 职责：表单校验、调用 AuthBiz 发起登录请求、更新 AuthViewModel、
 * 持久化凭证、pop 返回上一页。
 *
 * 分层：Controller → Biz → Imp → HttpUtil
 */
export class AuthController {
  private biz: AuthBiz = new AuthBiz()
  private vm: AuthViewModel

  constructor(vm: AuthViewModel) {
    this.vm = vm
  }

  /**
   * 发起登录。
   *
   * 1. 校验用户名/密码不为空
   * 2. 设置 isLoading = true，触发 UI 进入 loading 状态
   * 3. 调用 AuthBiz.login() → AuthImp → HttpUtil.post()
   * 4. 成功：更新 vm（userInfo / isLogin），持久化 token，pop 返回
   * 5. 失败：重置 isLoading，交由 UI 提示（当前静默处理）
   */
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
        // 清空密码，避免内存中长期留存明文
        this.vm.password = ''
        saveAuth(result.token, result.userName, result.userId)
        // pop 回上一页（已登录后不再 replace 到 Home，保持导航栈完整）
        HMUtil.pop()
      })
      .catch(() => {
        this.vm.isLoading = false
      })
  }
}
