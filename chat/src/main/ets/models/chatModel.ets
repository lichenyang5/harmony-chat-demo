/**
 * 单条聊天消息（响应式版本，UI 层用）
 *
 * 关键设计：@ObservedV2 + @Trace content
 * 流式生成时，Controller 直接 aiMessage.content += chunk，
 * @Trace 自动驱动对应 MessageBubble 重渲染，不需要重建数组、
 * 不需要前端打字机层。
 *
 * ⚠️ 注意：@Trace 修饰的字段在 JSON.stringify 时会丢失
 * （ArkUI 把它存到不可枚举的内部槽位）。
 * 因此持久化必须用 ChatMessagePlain（见下方），不能直接 stringify(ChatMessage)。
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
 * 没有 @Trace，所有字段都是普通 own property，
 * JSON.stringify / parse 来去自如。
 * 跟 ChatMessage 字段完全一致。
 */
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
}

// ApiResponse 已迁移到 common HAR (commonModel.ets)，此处删除避免重复

/**
 * 传给后端的历史上下文条目（不带 id / createTime 等元数据）
 *
 * 用 class 而不是 interface：
 * ArkTS 不允许对象字面量直接 as 到 interface / Record，
 * 必须能映射到明确的 class 类型，所以这里定义一个轻量 class。
 */
export class ChatHistoryItem {
  role: string = ''
  content: string = ''
}

export class ChatSession {
  id: string = ''
  title: string = ''
  preview: string = ''
  createTime: number = 0
  updateTime: number = 0
  messages: ChatMessage[] = []
}
