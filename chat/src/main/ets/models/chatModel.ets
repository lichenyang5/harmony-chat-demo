export class ChatMessage {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
}

// ApiResponse 已迁移到 common HAR (commonModel.ets)，此处删除避免重复

export class ChatSession {
  id: string = ''           // 会话唯一 ID（时间戳字符串）
  title: string = ''        // 标题：取第一条用户消息前 20 字
  preview: string = ''      // 列表预览：最后一条消息的前 30 字
  createTime: number = 0    // 创建时间（ms 时间戳）
  updateTime: number = 0    // 最后更新时间（ms 时间戳）
  messages: ChatMessage[] = []
}