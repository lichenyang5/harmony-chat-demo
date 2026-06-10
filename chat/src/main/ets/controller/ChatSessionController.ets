import { common } from '@kit.AbilityKit'
import { LogUtil } from 'common'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatSession, ChatMessage, ChatMessagePlain } from '../models/chatModel'
import { loadSessions, saveSession } from '../utils/ChatPersist'

/**
 * 聊天会话控制器。
 *
 * 职责：
 * - 会话 ID 初始化
 * - 按 ID 从持久化存储加载会话（ChatTabComp 使用）
 * - 从路由参数还原会话对象（ChatPage 使用）
 * - 新建会话
 * - 持久化当前会话
 *
 * 核心转换逻辑（ChatMessage ↔ ChatMessagePlain）：
 * - 存储用 ChatMessagePlain（普通对象，JSON.stringify 可序列化）
 * - UI 用 ChatMessage（@ObservedV2 / @Trace，驱动气泡实时更新）
 * - 两者之间的转换由 convertToObservable / convertToPlain 私有方法负责
 */
export class ChatSessionController {
  private vm: ChatViewModel

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  /**
   * 初始化会话 ID：若当前为空则以时间戳生成新 ID。
   * 在组件 aboutToAppear 中调用。
   */
  initSession(): void {
    if (!this.vm.sessionId) {
      this.vm.sessionId = Date.now().toString()
    }
  }

  /**
   * 按 ID 从 Preferences 加载会话并恢复到 ViewModel。
   *
   * Preferences 存储的是 ChatMessagePlain 普通对象，加载后需逐条
   * 转换为 ChatMessage（@ObservedV2），以恢复 @Trace 响应能力。
   *
   * @param id 目标会话 ID
   * @param ctx UIAbility 上下文（Preferences 读取需要）
   * @returns 加载成功返回 true，会话不存在返回 false
   */
  loadSessionById(id: string, ctx: common.UIAbilityContext): boolean {
    const sessions = loadSessions(ctx)
    const target = sessions.find((s: ChatSession) => s.id === id)

    if (!target) {
      LogUtil.w('ChatSessionController', 'session not found: ' + id)
      return false
    }

    const sourceMessages: ChatMessagePlain[] = target.messages ? target.messages : []
    const targetId = target.id ? target.id : id

    this.vm.historyMessage = this.convertToObservable(sourceMessages, targetId)
    this.vm.sessionId = targetId
    this.vm.inputContent = ''
    this.vm.isLoading = false
    return true
  }

  /**
   * 从 ChatSession 对象直接恢复到 ViewModel（ChatPage 从路由参数接收时使用）。
   *
   * @param session 路由参数传入的会话对象（含 ChatMessagePlain 消息列表）
   */
  restoreSession(session: ChatSession): void {
    const sessionId = session.id ? session.id : Date.now().toString()
    const sourceMessages: ChatMessagePlain[] = session.messages ? session.messages : []

    this.vm.historyMessage = this.convertToObservable(sourceMessages, sessionId)
    this.vm.sessionId = sessionId
    this.vm.inputContent = ''
    this.vm.isLoading = false
  }

  /**
   * 新建会话：重置 ViewModel 全部状态。
   * 若当前正在生成 AI 回复则忽略，防止中断流式请求。
   */
  newSession(): void {
    if (this.vm.isLoading) {
      return
    }
    this.vm.resetForNewSession()
  }

  /**
   * 将当前会话持久化到 Preferences。
   *
   * 注意：不能直接 JSON.stringify ChatMessage，@Trace 字段序列化会丢失。
   * 必须先逐条转换为 ChatMessagePlain，再序列化存储。
   *
   * @param ctx UIAbility 上下文（Preferences 写入需要）
   */
  persistSession(ctx: common.UIAbilityContext): void {
    if (this.vm.historyMessage.length === 0) {
      return
    }

    const plainMessages = this.convertToPlain()
    if (plainMessages.length === 0) {
      return
    }

    const session = this.buildSession(plainMessages)
    saveSession(ctx, session)
  }

  /**
   * 将 ChatMessage（@ObservedV2）数组转为 ChatMessagePlain 普通对象数组，用于持久化。
   * 每个字段均做空值防御，避免 @Trace 字段序列化时出现 undefined。
   */
  private convertToPlain(): ChatMessagePlain[] {
    return this.vm.historyMessage.map((source: ChatMessage, i: number) => {
      const plain = new ChatMessagePlain()
      plain.id = source.id ? source.id : `${this.vm.sessionId}_${i}`
      plain.role = source.role ? source.role : 'assistant'
      plain.content = source.content ? source.content : ''
      plain.createTime = source.createTime ? source.createTime : Date.now()
      plain.sessionId = source.sessionId ? source.sessionId : this.vm.sessionId
      // 卡片：PickupCard 是普通类，可直接序列化
      plain.card = source.card ? source.card : null
      return plain
    })
  }

  /**
   * 将 ChatMessagePlain 普通对象数组恢复为 ChatMessage（@ObservedV2）数组，用于 UI 展示。
   * 每个字段均做空值防御，fallback 到合理默认值。
   *
   * @param plains 持久化存储中读出的消息列表
   * @param sessionId 所属会话 ID，用于生成 fallback 消息 ID
   */
  private convertToObservable(plains: ChatMessagePlain[], sessionId: string): ChatMessage[] {
    return plains.map((plain: ChatMessagePlain, i: number) => {
      const msg = new ChatMessage()
      msg.id = plain.id ? plain.id : `${sessionId}_${i}`
      msg.role = plain.role ? plain.role : 'assistant'
      msg.content = plain.content ? plain.content : ''
      msg.createTime = plain.createTime ? plain.createTime : Date.now()
      msg.sessionId = plain.sessionId ? plain.sessionId : sessionId
      // 卡片：JSON.parse 出来的 plain.card 是普通对象，字段与 PickupCard 一致，
      // 直接赋值即可（PickupCard 上无方法，无需重建实例）
      msg.card = plain.card ? plain.card : null
      return msg
    })
  }

  /**
   * 根据消息列表构建 ChatSession 对象。
   *
   * - title：取第一条 user 消息的前 20 字
   * - preview：取最后一条消息的前 30 字
   * - createTime / updateTime：分别来自第一/最后一条消息的时间戳
   */
  private buildSession(plainMessages: ChatMessagePlain[]): ChatSession {
    const firstUser = plainMessages.find((m: ChatMessagePlain) => m.role === 'user')
    const firstContent = firstUser && firstUser.content ? firstUser.content : ''
    const title = firstContent.length > 0
      ? firstContent.substring(0, 20) + (firstContent.length > 20 ? '...' : '')
      : '新对话'

    const last = plainMessages[plainMessages.length - 1]
    const lastContent = last && last.content ? last.content : ''
    const preview = lastContent.length > 0
      ? lastContent.substring(0, 30) + (lastContent.length > 30 ? '...' : '')
      : '暂无回复'

    const first = plainMessages[0]
    const createTime = first && first.createTime ? first.createTime : Date.now()
    const updateTime = last && last.createTime ? last.createTime : Date.now()

    const session = new ChatSession()
    session.id = this.vm.sessionId ? this.vm.sessionId : Date.now().toString()
    session.title = title
    session.preview = preview
    session.createTime = createTime
    session.updateTime = updateTime
    session.messages = plainMessages
    return session
  }
}
