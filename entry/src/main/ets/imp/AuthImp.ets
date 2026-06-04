import { ApiConstants } from 'common'
import { ApiResponse } from 'common'
import { LoginRequest, UserInfo } from '../models/userModel'
import { HttpUtil } from 'common'

export class AuthImp {
  login(request: LoginRequest): Promise<ApiResponse<UserInfo>> {
    const body: Record<string, Object> = {
      'userName': request.userName,
      'password': request.password
    }
    return HttpUtil.post<UserInfo>(ApiConstants.LOGIN, body)
  }
}
