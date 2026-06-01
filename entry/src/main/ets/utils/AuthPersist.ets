import { PersistenceV2 } from '@kit.ArkUI'

@ObservedV2
export class AuthPersist {
  @Trace token: string = ''
  @Trace userName: string = ''
  @Trace userId: string = ''
}

export function getAuthPersist(): AuthPersist {
  return PersistenceV2.connect(AuthPersist, 'auth_persist', () => new AuthPersist())!
}

export function saveAuth(token: string, userName: string, userId: string): void {
  const persist = getAuthPersist()
  persist.token = token
  persist.userName = userName
  persist.userId = userId
}

export function clearAuth(): void {
  const persist = getAuthPersist()
  persist.token = ''
  persist.userName = ''
  persist.userId = ''
}

export function hasToken(): boolean {
  return getAuthPersist().token.length > 0
}
