import { UserInfo } from '../models/AuthModel'

@ObservedV2
export class AuthStore {
  @Trace token: string = ''
  @Trace userInfo: UserInfo | null = null

  get isLogin(): boolean {
    return this.token.length > 0 && this.userInfo !== null
  }

  setAuth(token: string, userInfo: UserInfo): void {
    this.token = token
    this.userInfo = userInfo
  }

  clearAuth(): void {
    this.token = ''
    this.userInfo = null
  }
}

export const globalAuthStore: AuthStore = new AuthStore()