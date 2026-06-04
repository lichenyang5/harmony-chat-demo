import { EntryRoutes } from '../constants/EntryRoutes'
import {
  HMInterceptor,
  HMInterceptorAction,
  HMInterceptorInfo,
  HMRouterMgr,
  IHMInterceptor
} from '@hadss/hmrouter'
import { hasToken } from '../utils/AuthPersist'

@HMInterceptor({ interceptorName: 'AuthInterceptor', priority: 99 })
export class AuthInterceptor implements IHMInterceptor {

  handle(info: HMInterceptorInfo): HMInterceptorAction {
    if (hasToken()) {
      console.log('[AuthInterceptor] 已登录，放行')
      return HMInterceptorAction.DO_NEXT
    }

    console.log('[AuthInterceptor] 未登录，弹登录提示')
    HMRouterMgr.push({ pageUrl: EntryRoutes.DIALOG_LOGIN_PROMPT })
    return HMInterceptorAction.DO_REJECT   // 拦截原跳转
  }
}