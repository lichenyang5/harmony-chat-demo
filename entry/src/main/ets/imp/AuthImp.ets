import { ApiConstants } from '../constants/ApiConstants'
import { ApiResponse } from '../models/chatModel'
import { LoginRequest, UserInfo } from '../models/userModel'
import { HttpUtil } from '../utils/HttpUtil'

export class AuthImp {
  login(request: LoginRequest): Promise<ApiResponse<UserInfo>> {
    const body: Record<string, Object> = {
      'userName': request.userName,
      'password': request.password
    }
    return HttpUtil.post<UserInfo>(ApiConstants.LOGIN, body)
  }
}
