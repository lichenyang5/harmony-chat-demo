import { ChatText } from '../constants/ChatConstants'

/**
 * 类型化错误系统
 *
 * 替代魔法字符串检测（旧代码里把 content 直接改成 '生成失败，请稍后重试'）。
 * 失败原因枚举化后：
 * - Controller 按 type 决定路由（用户气泡 FAILED 还是 AI 气泡 FAILED）；
 * - 日志里能看到精确原因，而不是一句笼统的“失败”；
 * - UI 文案由 type 映射，不再靠 match 字符串。
 */

/** 失败原因 */
export enum ChatErrorType {
  /** 传输层失败：连不上 / 超时 / 连接被重置（SseHttpUtil 的 onError 回调） */
  NETWORK_ERROR = 'NETWORK_ERROR',
  /** 服务端逻辑失败：done 帧里带了 error 字段 */
  SERVER_ERROR = 'SERVER_ERROR',
  /** 流正常结束，但一个字都没收到 */
  EMPTY_REPLY = 'EMPTY_REPLY',
}

/** 类型化错误对象 */
export class ChatError {
  type: ChatErrorType
  /** 原始错误信息（给开发看，进日志，不直接展示给用户） */
  message: string

  constructor(type: ChatErrorType, message: string = '') {
    this.type = type
    this.message = message
  }

  /** 传输层失败 */
  static network(message: string = ''): ChatError {
    return new ChatError(ChatErrorType.NETWORK_ERROR, message)
  }

  /** 服务端 done 帧带 error */
  static server(message: string = ''): ChatError {
    return new ChatError(ChatErrorType.SERVER_ERROR, message)
  }

  /** 流结束但无任何内容 */
  static empty(): ChatError {
    return new ChatError(ChatErrorType.EMPTY_REPLY)
  }

  /** 给用户看的友好文案（按 type 映射到 ChatText） */
  toUserHint(): string {
    switch (this.type) {
      case ChatErrorType.NETWORK_ERROR:
        return ChatText.ERR_NETWORK
      case ChatErrorType.SERVER_ERROR:
        return ChatText.ERR_SERVER
      case ChatErrorType.EMPTY_REPLY:
        return ChatText.ERR_EMPTY
      default:
        return ChatText.ERR_NETWORK
    }
  }
}
