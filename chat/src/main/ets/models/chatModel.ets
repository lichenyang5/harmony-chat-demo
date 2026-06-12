import { MessageStatus, isTerminal } from './MessageStatus'
import { ChatRole } from '../constants/ChatConstants'

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
 * 1. @ObservedV2 + @Trace content / card / status。
 * 2. 流式生成时，Controller 直接 aiMessage.content += chunk。
 * 3. @Trace 字段自动驱动对应 MessageBubble 重渲染。
 *
 * status 字段：见 MessageStatus —— 单一状态机，同一时刻只有一个状态，
 * 取代旧的「单全局 isLoading + 字符串拼 [已停止]」做法。
 *
 * card 字段：
 * - 普通文本回复时为 null；
 * - done 帧附带 card 数据时由 Controller 一次性赋值，切到卡片渲染分支。
 *
 * 注意：@Trace 字段不适合直接 JSON.stringify 持久化，
 * 所以读写存储统一走 fromPlain / toPlain 这层 mapper。
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
  /** 消息状态（持久化，驱动气泡渲染不同形态） */
  @Trace status: MessageStatus = MessageStatus.DONE
  /**
   * 失败时给用户看的提示文案（运行时态，不持久化）。
   * 由 Controller 从 ChatError.toUserHint() 写入；
   * 读回历史会话后为空串，UI 兜底为通用文案。
   */
  @Trace errorHint: string = ''

  /**
   * 从持久化纯对象恢复为响应式实例。
   *
   * 两件事：
   * 1. 逐字段空值防御（不信任历史脏数据 / 缺字段的老版本数据）。
   * 2. 中途态归一化：SENDING/THINKING/STREAMING 在 App 重启后不可能再续上，
   *    一律改写成 FAILED —— 历史里“卡在一半”的消息要显示成可重试，
   *    而不是永远转圈或假装在思考。
   *
   * @param plain     存储中读出的纯对象
   * @param sessionId 所属会话 ID，用于生成兜底消息 ID
   * @param index     在列表中的下标，用于生成兜底消息 ID
   */
  static fromPlain(plain: ChatMessagePlain, sessionId: string, index: number): ChatMessage {
    const msg = new ChatMessage()
    msg.id = plain.id ? plain.id : `${sessionId}_${index}`
    msg.role = plain.role ? plain.role : ChatRole.ASSISTANT
    msg.content = plain.content ? plain.content : ''
    msg.createTime = plain.createTime ? plain.createTime : Date.now()
    msg.sessionId = plain.sessionId ? plain.sessionId : sessionId
    // JSON.parse 出来的 plain.card 是普通对象，字段与 PickupCard/TripCard 一致，直接赋值
    msg.card = plain.card ? plain.card : null
    const raw: MessageStatus = plain.status ? plain.status : MessageStatus.DONE
    msg.status = isTerminal(raw) ? raw : MessageStatus.FAILED
    return msg
  }

  /**
   * 转为持久化纯对象。逐字段空值防御，避免 @Trace 字段序列化时出现 undefined。
   *
   * @param sessionId 当前会话 ID，用于兜底字段
   * @param index     列表下标，用于生成兜底消息 ID
   */
  toPlain(sessionId: string, index: number): ChatMessagePlain {
    const plain = new ChatMessagePlain()
    plain.id = this.id ? this.id : `${sessionId}_${index}`
    plain.role = this.role ? this.role : ChatRole.ASSISTANT
    plain.content = this.content ? this.content : ''
    plain.createTime = this.createTime ? this.createTime : Date.now()
    plain.sessionId = this.sessionId ? this.sessionId : sessionId
    plain.card = this.card ? this.card : null
    plain.status = this.status ? this.status : MessageStatus.DONE
    return plain
  }
}

/**
 * 单条聊天消息（纯数据版本，持久化用）
 *
 * 没有 @Trace，所有字段都是普通字段，JSON.stringify / RDB 列读写都正常。
 * 与 ChatMessage 之间的互转由 ChatMessage.fromPlain / toPlain 负责。
 */
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
  // 与 ChatMessage.card 同步用 Object 透传
  card: Object | null = null
  /** 消息状态（落库到 chat_message.status 列） */
  status: MessageStatus = MessageStatus.DONE
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
 * 注意：messages 必须使用 ChatMessagePlain[]，不能用 ChatMessage[]。
 */
export class ChatSession {
  id: string = ''
  title: string = ''
  preview: string = ''
  createTime: number = 0
  updateTime: number = 0
  messages: ChatMessagePlain[] = []
}
