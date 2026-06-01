import { AuthImp } from '../imp/AuthImp'
import { LoginRequest, UserInfo } from '../models/userModel'

export class AuthBiz {
  private imp: AuthImp = new AuthImp()

  login(params: LoginRequest): Promise<UserInfo | null> {
    return this.imp.login(params).then((result) => {
      if (result.code === 200) {
        return result.data
      }
      return null
    })
  }
}