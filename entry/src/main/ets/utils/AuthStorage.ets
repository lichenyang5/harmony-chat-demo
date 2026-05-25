import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { UserInfo } from '../models/AuthModel'

interface AuthCacheData {
  token: string
  userInfo: UserInfo
}

export class AuthStorage {
  private static readonly STORE_NAME: string = 'auth_storage'
  private static readonly AUTH_CACHE_KEY: string = 'auth_cache'

  static async saveAuthCache(
    context: common.UIAbilityContext,
    token: string,
    userInfo: UserInfo
  ): Promise<void> {
    const pref = await preferences.getPreferences(context, AuthStorage.STORE_NAME)

    const cacheData: AuthCacheData = {
      token,
      userInfo
    }

    await pref.put(AuthStorage.AUTH_CACHE_KEY, JSON.stringify(cacheData))
    await pref.flush()
  }

  static async getAuthCache(context: common.UIAbilityContext): Promise<AuthCacheData | null> {
    const pref = await preferences.getPreferences(context, AuthStorage.STORE_NAME)
    const cacheValue = await pref.get(AuthStorage.AUTH_CACHE_KEY, '')

    if (typeof cacheValue !== 'string' || cacheValue.length === 0) {
      return null
    }

    try {
      const cacheData = JSON.parse(cacheValue) as AuthCacheData

      if (!cacheData.token || !cacheData.userInfo) {
        return null
      }

      return cacheData
    } catch (error) {
      console.error(`parse auth cache error: ${JSON.stringify(error)}`)
      return null
    }
  }

  static async clearAuthCache(context: common.UIAbilityContext): Promise<void> {
    const pref = await preferences.getPreferences(context, AuthStorage.STORE_NAME)
    await pref.delete(AuthStorage.AUTH_CACHE_KEY)
    await pref.flush()
  }
}