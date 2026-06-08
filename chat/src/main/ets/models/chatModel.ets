/**
 * 上车点
 *
 * 后端 done 帧里 card.points[] 的单项结构。
 */
export class PickupPoint {
  index: number = 0
  name: string = ''
  address: string = ''
  distance: string = ''
  entrance: string = ''
}

/**
 * 确认上车点卡片
 *
 * 后端在 done 帧附带 card 字段时下发的结构化数据。
 * type 字段用于将来扩展更多卡片种类（pickup_confirm / ...）。
 */
export class PickupCard {
  type: string = ''
  title: string = ''
  question: string = ''
  currentLocation: string = ''
  points: PickupPoint[] = []
  moreText: string = ''
}

/**
 * 单条聊天消息（响应式版本，UI 层用）
 *
 * 关键设计：
 * 1. @ObservedV2 + @Trace content。
 * 2. 流式生成时，Controller 直接 aiMessage.content += chunk。
 * 3. @Trace content 自动驱动对应 MessageBubble 重渲染。
 *
 * card 字段：
 * - 普通文本回复时为 null；
 * - 当后端 done 帧附带 card 数据时由 Controller 一次性赋值，
 *   驱动 MessageBubble 切换到卡片渲染分支。
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
  @Trace card: PickupCard | null = null
}

/**
 * 单条聊天消息（纯数据版本，持久化用）
 *
 * 没有 @Trace，所有字段都是普通字段。
 * JSON.stringify / JSON.parse 都能正常保存和恢复。
 *
 * card 字段：
 * PickupCard / PickupPoint 都是普通 class，JSON 往返不会丢字段。
 * 读回时是 plain object，赋给 ChatMessage.card 字段类型一致，
 * runtime 字段访问无差异（PickupCard 上无方法）。
 */
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
  card: PickupCard | null = null
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