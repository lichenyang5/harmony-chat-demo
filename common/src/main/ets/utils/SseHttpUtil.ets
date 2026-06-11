import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { ApiConstants } from '../constants/ApiConstants'
import { LogUtil } from './LogUtil'
import { getNetMonitor } from '../debug/NetMonitor'

/**
 * SSE 流结束帧的元信息
 *
 * card 是后端在结束帧里可选附带的结构化卡片数据。
 * common 层不感知具体业务结构，统一以 Object 透传，
 * 由业务侧（如 ChatController）映射成具体类型。
 */
export interface SseDoneMeta {
  sessionId?: string
  messageId?: string
  error?: string
  card?: Object
}

/**
 * SSE 每一帧的数据结构
 *
 * 注意：
 * ArkTS 不支持 TS 里的交叉类型：
 * SseDoneMeta & { chunk?: string, done?: boolean }
 *
 * 所以这里用 interface extends 的方式替代。
 */
interface SseFrame extends SseDoneMeta {
  chunk?: string
  done?: boolean
}

/**
 * SSE 流式请求的回调
 */
export interface SseCallbacks {
  onChunk: (chunk: string) => void
  onDone: (meta: SseDoneMeta) => void
  onError: (errMsg: string) => void
}

/**
 * SSE / Server-Sent Events 流式 HTTP 工具
 *
 * 协议要点：
 * - Content-Type: text/event-stream
 * - 每条消息格式：data: <json>\n\n
 * - 客户端用 buffer 累积，按 \n\n 切分出完整帧再解析
 *
 * 返回 HttpRequest 实例：
 * - 调用方可以保存它
 * - 需要中断时调用 destroy()
 */
export class SseHttpUtil {
  static postStream(
    path: string,
    body: Record<string, Object>,
    callbacks: SseCallbacks
  ): http.HttpRequest {
    // 上报到应用内网络调试面板（release 包为空操作）
    const monitor = getNetMonitor()
    const rec = monitor.begin('SSE', ApiConstants.BASE_URL + path, JSON.stringify(body))

    const req = http.createHttp()

    // SSE 帧可能跨 chunk 到达，必须用 buffer 累积再切分
    let buffer: string = ''
    const decoder = util.TextDecoder.create('utf-8')

    // 已经触发过 onDone 的标记，避免重复回调
    let doneFired: boolean = false

    req.on('dataReceive', (data: ArrayBuffer) => {
      // ArrayBuffer 转 string
      // stream: true 用来处理中文多字节字符跨包问题
      const text = decoder.decodeToString(new Uint8Array(data), { stream: true })
      buffer += text

      // 按 \n\n 切分出“完整帧 + 残段”
      const parts = buffer.split('\n\n')
      buffer = parts.pop() ?? ''

      for (const part of parts) {
        const line = part.trim()

        if (!line.startsWith('data:')) {
          continue
        }

        const jsonStr = line.substring(5).trim()

        try {
          const frame = JSON.parse(jsonStr) as SseFrame

          if (frame.done === true) {
            doneFired = true

            monitor.addFrame(rec, 'done', jsonStr)
            if (frame.card) {
              monitor.setCard(rec, JSON.stringify(frame.card, null, 2))
            }
            if (frame.error) {
              monitor.noteError(rec, frame.error)
            }

            callbacks.onDone({
              sessionId: frame.sessionId,
              messageId: frame.messageId,
              error: frame.error,
              card: frame.card
            })
          } else if (frame.chunk !== undefined) {
            monitor.addFrame(rec, 'chunk', jsonStr)
            monitor.appendText(rec, frame.chunk)
            callbacks.onChunk(frame.chunk)
          }
        } catch (e) {
          monitor.addFrame(rec, 'raw', jsonStr)
          LogUtil.e('SseHttpUtil', 'parse frame failed: ' + jsonStr)
        }
      }
    })

    req.on('dataEnd', () => {
      monitor.endStream(rec)

      // 兜底：如果服务端没发结束帧就断了，也触发一次 onDone
      if (!doneFired) {
        callbacks.onDone({})
      }

      try {
        req.destroy()
      } catch (_) {}
    })

    req.requestInStream(
      ApiConstants.BASE_URL + path,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 60000
      }
    ).then((code: number) => {
      monitor.onSseStatus(rec, code)
    }).catch((err: Error) => {
      monitor.fail(rec, JSON.stringify(err))
      callbacks.onError(JSON.stringify(err))

      try {
        req.destroy()
      } catch (_) {}
    })

    return req
  }
}