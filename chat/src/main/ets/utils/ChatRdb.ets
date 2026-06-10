import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LogUtil } from 'common'
import { ChatSession, ChatMessagePlain } from '../models/chatModel'

const DB_NAME: string = 'chat.db'
const TAG: string = 'ChatRdb'

const SQL_CREATE_SESSION: string = `
  CREATE TABLE IF NOT EXISTS chat_session (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    preview TEXT,
    create_time INTEGER NOT NULL,
    update_time INTEGER NOT NULL
  )
`

const SQL_CREATE_MESSAGE: string = `
  CREATE TABLE IF NOT EXISTS chat_message (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT,
    create_time INTEGER NOT NULL,
    card_json TEXT
  )
`

const SQL_CREATE_INDEX: string = `
  CREATE INDEX IF NOT EXISTS idx_msg_session
  ON chat_message(session_id, create_time)
`

export class ChatRdb {
  private static store: relationalStore.RdbStore | null = null

  /** 初始化（在 EntryAbility.onCreate / aboutToAppear 调一次即可） */
  static async init(ctx: common.UIAbilityContext): Promise<void> {
    if (ChatRdb.store !== null) return

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    try {
      ChatRdb.store = await relationalStore.getRdbStore(ctx, config)
      await ChatRdb.store.executeSql(SQL_CREATE_SESSION)
      await ChatRdb.store.executeSql(SQL_CREATE_MESSAGE)
      await ChatRdb.store.executeSql(SQL_CREATE_INDEX)
      LogUtil.i(TAG, 'init success')
    } catch (e) {
      LogUtil.e(TAG, 'init failed: ' + JSON.stringify(e))
    }
  }

  /** 加载所有会话（不含 messages 本体，懒加载） */
  static async loadSessions(): Promise<ChatSession[]> {
    if (ChatRdb.store === null) return []
    const list: ChatSession[] = []
    try {
      const pred = new relationalStore.RdbPredicates('chat_session')
      pred.orderByDesc('update_time')
      const rs = await ChatRdb.store.query(
        pred, ['id', 'title', 'preview', 'create_time', 'update_time']
      )
      while (rs.goToNextRow()) {
        const s = new ChatSession()
        s.id = rs.getString(rs.getColumnIndex('id'))
        s.title = rs.getString(rs.getColumnIndex('title'))
        s.preview = rs.getString(rs.getColumnIndex('preview'))
        s.createTime = rs.getLong(rs.getColumnIndex('create_time'))
        s.updateTime = rs.getLong(rs.getColumnIndex('update_time'))
        // 注意：messages 留空，需要时按 sessionId 单独查
        list.push(s)
      }
      rs.close()
    } catch (e) {
      LogUtil.e(TAG, 'loadSessions failed: ' + JSON.stringify(e))
    }
    return list
  }

  /** 加载某个会话的全部消息（按时间正序） */
  static async loadMessages(sessionId: string): Promise<ChatMessagePlain[]> {
    if (ChatRdb.store === null) return []
    const list: ChatMessagePlain[] = []
    try {
      const pred = new relationalStore.RdbPredicates('chat_message')
      pred.equalTo('session_id', sessionId)
      pred.orderByAsc('create_time')
      const rs = await ChatRdb.store.query(pred)
      while (rs.goToNextRow()) {
        const m = new ChatMessagePlain()
        m.id = rs.getString(rs.getColumnIndex('id'))
        m.sessionId = rs.getString(rs.getColumnIndex('session_id'))
        m.role = rs.getString(rs.getColumnIndex('role'))
        m.content = rs.getString(rs.getColumnIndex('content'))
        m.createTime = rs.getLong(rs.getColumnIndex('create_time'))
        const cardJson = rs.getString(rs.getColumnIndex('card_json'))
        m.card = cardJson.length > 0 ? (JSON.parse(cardJson) as Object) : null
        list.push(m)
      }
      rs.close()
    } catch (e) {
      LogUtil.e(TAG, 'loadMessages failed: ' + JSON.stringify(e))
    }
    return list
  }

  /** 保存（新增或覆盖）一个会话 + 它的所有消息 */
  static async saveSession(session: ChatSession): Promise<void> {
    if (ChatRdb.store === null) return
    if (session.messages.length === 0) return

    try {
      // 1. 上 session 表（先删再插，最简方案）
      const sPred = new relationalStore.RdbPredicates('chat_session')
      sPred.equalTo('id', session.id)
      await ChatRdb.store.delete(sPred)

      const sValues: relationalStore.ValuesBucket = {
        'id': session.id,
        'title': session.title,
        'preview': session.preview,
        'create_time': session.createTime,
        'update_time': session.updateTime
      }
      await ChatRdb.store.insert('chat_session', sValues)

      // 2. 上 message 表（同 sessionId 全部清掉再批量插）
      const mPred = new relationalStore.RdbPredicates('chat_message')
      mPred.equalTo('session_id', session.id)
      await ChatRdb.store.delete(mPred)

      for (let i = 0; i < session.messages.length; i++) {
        const m = session.messages[i]
        const mValues: relationalStore.ValuesBucket = {
          'id': m.id,
          'session_id': session.id,
          'role': m.role,
          'content': m.content,
          'create_time': m.createTime,
          'card_json': m.card !== null ? JSON.stringify(m.card) : ''
        }
        await ChatRdb.store.insert('chat_message', mValues)
      }
      LogUtil.i(TAG, `saveSession ok, id=${session.id}, msgs=${session.messages.length}`)
    } catch (e) {
      LogUtil.e(TAG, 'saveSession failed: ' + JSON.stringify(e))
    }
  }

  /** 删除指定会话 + 它的所有消息 */
  static async deleteSession(sessionId: string): Promise<void> {
    if (ChatRdb.store === null) return
    try {
      const sPred = new relationalStore.RdbPredicates('chat_session')
      sPred.equalTo('id', sessionId)
      await ChatRdb.store.delete(sPred)

      const mPred = new relationalStore.RdbPredicates('chat_message')
      mPred.equalTo('session_id', sessionId)
      await ChatRdb.store.delete(mPred)
    } catch (e) {
      LogUtil.e(TAG, 'deleteSession failed: ' + JSON.stringify(e))
    }
  }
}