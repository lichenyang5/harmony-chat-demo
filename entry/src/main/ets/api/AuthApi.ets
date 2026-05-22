import { http } from '@kit.NetworkKit'
import { API_BASE_URL } from '../constants/ApiConstants'
import { LoginRequest, LoginResponse } from '../models/AuthModel'

interface RequestHeader {
  'Content-Type': string
}

export function login(params: LoginRequest): Promise<LoginResponse> {
  return new Promise((resolve, reject) => {
    const httpRequest = http.createHttp()

    const requestHeader: RequestHeader = {
      'Content-Type': 'application/json'
    }

    const requestOptions: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: requestHeader,
      extraData: JSON.stringify(params),
      connectTimeout: 10000,
      readTimeout: 10000
    }

    const requestUrl: string = `${API_BASE_URL}/api/login`

    console.info(`login api request url: ${requestUrl}`)
    console.info(`login api request body: ${JSON.stringify(params)}`)

    httpRequest.request(requestUrl, requestOptions, (err, data) => {
      httpRequest.destroy()

      if (err) {
        console.error(`login api request error: ${JSON.stringify(err)}`)
        reject(err)
        return
      }

      try {
        const rawResult: string = String(data.result)

        console.info(`login api response code: ${data.responseCode}`)
        console.info(`login api response result: ${rawResult}`)

        const result: LoginResponse = JSON.parse(rawResult) as LoginResponse
        resolve(result)
      } catch (parseError) {
        console.error(`login api parse error: ${JSON.stringify(parseError)}`)
        reject(parseError)
      }
    })
  })
}