/**
 * 卡片基本字段
 *
 * 所有业务卡片在 JSON 上都必须带 type 字段，
 * 渲染层通过 type 分发到具体卡片组件（pickup_confirm / trip_confirm / ...）。
 */
export interface AgentCard {
  type: string
}

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
 * 确认上车点卡片（type = 'pickup_confirm'）
 */
export class PickupCard {
  type: string = 'pickup_confirm'
  title: string = ''
  question: string = ''
  currentLocation: string = ''
  points: PickupPoint[] = []
  moreText: string = ''
}

/**
 * 确认行程卡片（type = 'trip_confirm'）
 *
 * 后端识别 "确认打车" 意图后下发，
 * 字段对应卡片上「起点 / 距离时长 / 终点 / 价格 / 按钮」每一行的文本。
 */
export class TripCard {
  type: string = 'trip_confirm'
  title: string = ''
  startLocation: string = ''
  startTag: string = ''
  distance: string = ''
  duration: string = ''
  endLocation: string = ''
  arriveTime: string = ''
  priceRange: string = ''
  selectCarText: string = ''
  selectedHint: string = ''
  confirmText: string = ''
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
  // 卡片字段统一以 Object 透传，渲染层按 (card as AgentCard).type 分发到具体卡片组件
  @Trace card: Object | null = null
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
  // 与 ChatMessage.card 同步用 Object 透传
  card: Object | null = null
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