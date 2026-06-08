import { http } from '@kit.NetworkKit'
import { ApiConstants } from '../constants/ApiConstants'
import { ApiResponse } from '../models/commonModel'

export class HttpUtil {
  static post<T>(path: string, body: Record<string, Object>): Promise<ApiResponse<T>> {
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
    ).then(res => {
      return JSON.parse(res.result as string) as ApiResponse<T>
    }).finally(() => {
      req.destroy()
    })
  }

  static get<T>(path: string): Promise<ApiResponse<T>> {
    const req = http.createHttp()
    return req.request(
      ApiConstants.BASE_URL + path,
      {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000
      }
    ).then(res => {
      return JSON.parse(res.result as string) as ApiResponse<T>
    }).finally(() => {
      req.destroy()
    })
  }
}
