import { common } from '@kit.AbilityKit'
import { ChatSession } from '../models/chatModel'
import { getChatLoadState } from '../viewmodel/ChatLoadState'
import { HMUtil } from 'common'
import { ChatRdb } from '../utils/ChatRdb'

/**
 * 消息记录页控制器。
 *
 * 职责：
 * - 从持久化存储加载会话列表
 * - 删除单条会话（持久化 + 本地列表同步）
 * - 通过全局信号触发 ChatTabComp 加载指定历史会话
 * - 时间戳格式化
 */
export class ChatHistoryController {
  /**
   * 从 Preferences 读取所有会话，按 updateTime 倒序排列。
   *
   * @param ctx UIAbility 上下文（Preferences 读取需要）
   * @returns 会话列表，读取失败时返回空数组
   */
  async  loadData(ctx: common.UIAbilityContext): Promise<ChatSession[]> {
    return await ChatRdb.loadSessions()
  }

  /**
   * 删除指定会话。
   *
   * 先从 RDB 删除（session 表 + 该 sessionId 的所有 message 行），
   * 再从传入列表中过滤掉对应项并返回新列表。
   * 使用本地过滤而非重新查询数据库，避免列表闪烁。
   *
   * @param ctx UIAbility 上下文（保留签名兼容，ChatRdb 不依赖 ctx）
   * @param sessionId 要删除的会话 ID
   * @param sessions 当前页面持有的会话列表
   * @returns 移除后的新列表
   */
  async deleteSession(ctx: common.UIAbilityContext, sessionId: string,
    sessions: ChatSession[]): Promise<ChatSession[]> {
    await ChatRdb.deleteSession(sessionId)
    // 通知 ChatTabComp：若它当前正在显示这个会话，需要重置
    getChatLoadState().deletedSessionId = sessionId
    return sessions.filter((s: ChatSession) => s.id !== sessionId)
  }

  /**
   * 设置全局加载信号并 pop 回首页，触发 ChatTabComp 加载该会话。
   *
   * 信号流：
   * ChatHistoryPage 调用 openSession
   * → ChatLoadState.pendingSessionId 被设置
   * → HomePage @Monitor 切换到 Chat Tab（index = 1）
   * → ChatTabComp @Monitor 调用 loadSessionById 恢复会话
   *
   * @param sessionId 要打开的会话 ID
   */
  openSession(sessionId: string): void {
    getChatLoadState().pendingSessionId = sessionId
    HMUtil.pop()
  }

  /**
   * 将时间戳格式化为友好的可读字符串。
   * 今天的时间显示 HH:mm，历史日期显示 M/D。
   *
   * @param ms 时间戳（毫秒）
   * @returns 格式化后的字符串
   */
  formatTime(ms: number): string {
    const d = new Date(ms)
    const now = new Date()
    const isToday = d.toDateString() === now.toDateString()

    if (isToday) {
      return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
    }
    return `${d.getMonth() + 1}/${d.getDate()}`
  }
}
