import { common } from '@kit.AbilityKit'
import { LogUtil } from 'common'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatSession, ChatMessage, ChatMessagePlain } from '../models/chatModel'
import { ChatRole } from '../constants/ChatConstants'
import { ChatRdb } from '../utils/ChatRdb'

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
 * - 存储用 ChatMessagePlain（普通对象，可序列化 / RDB 列读写）
 * - UI 用 ChatMessage（@ObservedV2 / @Trace，驱动气泡实时更新）
 * - 两者之间的转换下沉到模型自身：ChatMessage.fromPlain / toPlain
 *   （含空值防御 + 中途态归一化），Controller 只负责调度，不再手写映射
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
   * 按 ID 从 RDB 加载会话消息并恢复到 ViewModel。
   *
   * RDB 中 chat_message 表存的是 ChatMessagePlain 普通对象的字段，
   * 加载后需逐条转换为 ChatMessage（@ObservedV2），以恢复 @Trace 响应能力。
   *
   * @param id 目标会话 ID
   * @param ctx UIAbility 上下文（保留签名兼容，ChatRdb 不依赖 ctx）
   * @returns 加载成功返回 true，会话不存在（无消息）返回 false
   */
  async loadSessionById(id: string, ctx: common.UIAbilityContext): Promise<boolean> {
    const sourceMessages: ChatMessagePlain[] = await ChatRdb.loadMessages(id)

    if (sourceMessages.length === 0) {
      LogUtil.w('ChatSessionController', 'session not found or empty: ' + id)
      return false
    }

    this.vm.historyMessage = sourceMessages.map((plain: ChatMessagePlain, i: number) =>
      ChatMessage.fromPlain(plain, id, i))
    this.vm.sessionId = id
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

    this.vm.historyMessage = sourceMessages.map((plain: ChatMessagePlain, i: number) =>
      ChatMessage.fromPlain(plain, sessionId, i))
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
   * 将当前会话持久化到 RDB（session 元数据 + 所有 message 行）。
   *
   * 注意：不能直接 JSON.stringify ChatMessage，@Trace 字段序列化会丢失。
   * 必须先逐条转换为 ChatMessagePlain，再交给 ChatRdb 写表。
   *
   * @param ctx UIAbility 上下文（保留签名兼容，ChatRdb 不依赖 ctx）
   */
  async persistSession(ctx: common.UIAbilityContext): Promise<void> {
    if (this.vm.historyMessage.length === 0) {
      return
    }

    const plainMessages: ChatMessagePlain[] = this.vm.historyMessage.map(
      (m: ChatMessage, i: number) => m.toPlain(this.vm.sessionId, i))
    if (plainMessages.length === 0) {
      return
    }

    const session = this.buildSession(plainMessages)
    await ChatRdb.saveSession(session)
  }

  /**
   * 根据消息列表构建 ChatSession 对象。
   *
   * - title：取第一条 user 消息的前 20 字
   * - preview：取最后一条消息的前 30 字
   * - createTime / updateTime：分别来自第一/最后一条消息的时间戳
   */
  private buildSession(plainMessages: ChatMessagePlain[]): ChatSession {
    const firstUser = plainMessages.find((m: ChatMessagePlain) => m.role === ChatRole.USER)
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
