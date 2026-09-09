import { ChatSession } from '../models/chatModel'
import { ChatRdb } from '../utils/ChatRdb'

/**
 * 历史会话控制器。
 *
 * 职责：
 * - 从持久化存储加载会话列表
 * - 删除单条会话（持久化 + 本地列表同步）
 * - 时间戳格式化
 */
export class ChatHistoryController {
  /**
   * 从 RDB 读取所有会话，并为 UI 再做一次更新时间倒序保护。
   */
  async loadData(): Promise<ChatSession[]> {
    const sessions = await ChatRdb.loadSessions()
    return sessions.sort((left: ChatSession, right: ChatSession) => right.updateTime - left.updateTime)
  }

  /**
   * 删除指定会话。
   *
   * 先从 RDB 删除（session 表 + 该 sessionId 的所有 message 行），
   * 再从传入列表中过滤掉对应项并返回新列表。
   * 使用本地过滤而非重新查询数据库，避免列表闪烁。
   *
   * @param sessionId 要删除的会话 ID
   * @param sessions 当前抽屉持有的会话列表
   * @returns 删除成功时返回新列表，数据库操作失败时返回 null
   */
  async deleteSession(sessionId: string, sessions: ChatSession[]): Promise<ChatSession[] | null> {
    const deleted = await ChatRdb.deleteSession(sessionId)
    if (!deleted) {
      return null
    }
    return sessions.filter((s: ChatSession) => s.id !== sessionId)
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
