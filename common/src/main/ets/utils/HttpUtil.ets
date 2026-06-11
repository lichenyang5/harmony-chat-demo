import { http } from '@kit.NetworkKit'
import { ApiConstants } from '../constants/ApiConstants'
import { ApiResponse } from '../models/commonModel'
import { getNetMonitor } from '../debug/NetMonitor'

export class HttpUtil {
  static post<T>(path: string, body: Record<string, Object>): Promise<ApiResponse<T>> {
    // 上报到应用内网络调试面板（release 包为空操作）
    const rec = getNetMonitor().begin('POST', ApiConstants.BASE_URL + path, JSON.stringify(body))
    const req = http.createHttp()
    return req.request(
      ApiConstants.BASE_URL + path,
      {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 10000
      }
    ).then((res: http.HttpResponse) => {
      getNetMonitor().finish(rec, res.responseCode, res.result as string)
      return JSON.parse(res.result as string) as ApiResponse<T>
    }).catch((err: Error) => {
      getNetMonitor().fail(rec, err.message ? err.message : JSON.stringify(err))
      // 保持原有错误传播，调用方行为不变
      throw err as Error
    }).finally(() => {
      req.destroy()
    })
  }

  static get<T>(path: string): Promise<ApiResponse<T>> {
    const rec = getNetMonitor().begin('GET', ApiConstants.BASE_URL + path, '')
    const req = http.createHttp()
    return req.request(
      ApiConstants.BASE_URL + path,
      {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000
      }
    ).then((res: http.HttpResponse) => {
      getNetMonitor().finish(rec, res.responseCode, res.result as string)
      return JSON.parse(res.result as string) as ApiResponse<T>
    }).catch((err: Error) => {
      getNetMonitor().fail(rec, err.message ? err.message : JSON.stringify(err))
      throw err as Error
    }).finally(() => {
      req.destroy()
    })
  }
}
