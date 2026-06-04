/**
 * 单条聊天消息（响应式版本，UI 层用）
 *
 * 关键设计：
 * 1. @ObservedV2 + @Trace content。
 * 2. 流式生成时，Controller 直接 aiMessage.content += chunk。
 * 3. @Trace content 自动驱动对应 MessageBubble 重渲染。
 *
 * 注意：
 * @Trace 字段不适合直接 JSON.stringify 持久化。
 * 所以保存历史记录时，必须先转成 ChatMessagePlain。
 */
@ObservedV2
export class ChatMessage {
  id: string = ''
  role: string = ''
  @Trace content: string = ''
  createTime: number = 0
  sessionId: string = ''
}

/**
 * 单条聊天消息（纯数据版本，持久化用）
 *
 * 没有 @Trace，所有字段都是普通字段。
 * JSON.stringify / JSON.parse 都能正常保存和恢复。
 */
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
}

/**
 * 传给后端的历史上下文条目
 */
export class ChatHistoryItem {
  role: string = ''
  content: string = ''
}

/**
 * 单个会话
 *
 * 注意：
 * messages 必须使用 ChatMessagePlain[]，
 * 不能用 ChatMessage[]。
 */
export class ChatSession {
  id: string = ''
  title: string = ''
  preview: string = ''
  createTime: number = 0
  updateTime: number = 0
  messages: ChatMessagePlain[] = []
}