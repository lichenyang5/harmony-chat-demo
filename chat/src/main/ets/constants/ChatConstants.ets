/**
 * Chat 模块常量
 *
 * 把散落在各处的魔法字符串（角色名、状态文案）收口到一处：
 * - 避免 'user' / 'assistant' 这类字面量四处拼写、漂移；
 * - UI 文案集中，后续做多语言 / 改文案只改这里。
 */

/** 消息角色 */
export enum ChatRole {
  USER = 'user',
  ASSISTANT = 'assistant',
}

/** UI 展示文案 */
export class ChatText {
  /** AI 等待首 token 时的占位 */
  static readonly THINKING: string = '思考中'
  /** 用户主动停止后的独立提示（渲染成分割线 + 这行字，不拼进正文） */
  static readonly STOPPED: string = '已停止生成'
  /** 失败用户气泡的重发入口 */
  static readonly RESEND: string = '重新发送'
  /** AI 气泡的重新生成入口 */
  static readonly REGENERATE: string = '重新生成'
  /** 历史会话里某条 AI 消息内容缺失时的兜底 */
  static readonly CONTENT_MISSING: string = '该条回复内容未保存完整'

  // —— 失败文案（与 ChatErrorType 一一对应）——
  static readonly ERR_NETWORK: string = '网络异常，请检查连接后重试'
  static readonly ERR_SERVER: string = '服务开小差了，请稍后重试'
  static readonly ERR_EMPTY: string = '没有收到回复，请重试'
}
