import BuildProfile from '../../../../BuildProfile'

export class ApiConstants {
  static readonly BASE_URL: string = BuildProfile.API_BASE_URL
  static readonly LOGIN: string = '/api/login'
  static readonly CHAT: string = '/api/chat'
  static readonly PRODUCTS: string = '/api/products'
}
