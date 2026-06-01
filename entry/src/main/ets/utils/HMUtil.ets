import { HMRouterMgr, HMRouterPathInfo, HMRouterPathCallback } from '@hadss/hmrouter'

export class HMUtil {
  static push(pathInfo: HMRouterPathInfo, callback?: HMRouterPathCallback): void {
    HMRouterMgr.push(pathInfo, callback)
  }

  static pop(pathInfo?: HMRouterPathInfo): void {
    HMRouterMgr.pop(pathInfo)
  }

  static replace(pathInfo: HMRouterPathInfo): void {
    HMRouterMgr.replace(pathInfo)
  }
}
