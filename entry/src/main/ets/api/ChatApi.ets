import { http } from '@kit.NetworkKit'
import { API_BASE_URL } from '../constants/ApiConstants'

export interface ChatRequest {
  conversationId?: number
  content: string
}

export interface ChatMessageDTO {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}

export interface ChatResponseData {
  conversationId: number
  messages: ChatMessageDTO[]
}

export interface ChatResponse {
  code: number
  message: string
  data: ChatResponseData
}

interface RequestHeader {
  'Content-Type': string
}

export function sendChatMessage(params: ChatRequest): Promise<ChatResponse> {
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

    const requestUrl: string = `${API_BASE_URL}/api/chat`

    console.info(`chat api request url: ${requestUrl}`)
    console.info(`chat api request body: ${JSON.stringify(params)}`)

    httpRequest.request(requestUrl, requestOptions, (err, data) => {
      httpRequest.destroy()

      if (err) {
        console.error(`chat api request error: ${JSON.stringify(err)}`)
        reject(err)
        return
      }

      try {
        const rawResult: string = String(data.result)

        console.info(`chat api response code: ${data.responseCode}`)
        console.info(`chat api response result: ${rawResult}`)

        const result: ChatResponse = JSON.parse(rawResult) as ChatResponse
        resolve(result)
      } catch (parseError) {
        console.error(`chat api parse error: ${JSON.stringify(parseError)}`)
        reject(parseError)
      }
    })
  })
}