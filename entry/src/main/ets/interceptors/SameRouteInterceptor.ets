import {
  HMInterceptorAction,
  HMInterceptorInfo,
  IHMInterceptor
} from '@hadss/hmrouter'

export class SameRouteInterceptor implements IHMInterceptor {
  interceptorName: string = 'SameRouteInterceptor'
  priority: number = 100

  handle(info: HMInterceptorInfo): HMInterceptorAction {
    const fromPage: string = info.srcName ?? ''
    const targetPage: string = info.targetName ?? ''

    console.log(`[SameRouteInterceptor] from=${fromPage}, target=${targetPage}`)

    if (fromPage.length > 0 && targetPage.length > 0 && fromPage === targetPage) {
      console.log('[SameRouteInterceptor] 相同路由，拦截跳转')
      return HMInterceptorAction.DO_REJECT
    }

    return HMInterceptorAction.DO_NEXT
  }
}