import { UserInfo } from '../models/userModel'

@ObservedV2
export class AuthViewModel {
  @Trace userName: string = ''
  @Trace password: string = ''
  @Trace isLoading: boolean = false
  @Trace isLogin: boolean = false
  @Trace userInfo: UserInfo | null = null
}