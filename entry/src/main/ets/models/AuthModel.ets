export interface LoginRequest {
  username: string
  password: string
}

export interface UserInfo {
  id: number
  username: string
  nickname: string
  avatar: string
}

export interface LoginResponseData {
  token: string
  userInfo: UserInfo
}

export interface LoginResponse {
  code: number
  message: string
  data: LoginResponseData
}