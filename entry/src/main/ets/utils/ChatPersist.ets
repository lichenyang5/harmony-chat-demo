import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { ChatSession } from '../models/chatModel'

const STORE_NAME = 'chat_history'   // Preferences 文件名（一个 App 可以有多个）
const KEY_SESSIONS = 'sessions'     // 存会话列表的 key

/**
 * 获取 Preferences 实例（同步版，API 10+）
 * context 必须是 UIAbilityContext（从 getHostContext() 拿）
 */
function getStore(ctx: common.UIAbilityContext): preferences.Preferences {
  return preferences.getPreferencesSync(ctx, { name: STORE_NAME })
}

/** 读取所有历史会话，按 updateTime 倒序 */
export function loadSessions(ctx: common.UIAbilityContext): ChatSession[] {
  try {
    const store = getStore(ctx)
    const raw = store.getSync(KEY_SESSIONS, '[]') as string
    const list = JSON.parse(raw) as ChatSession[]
    // 倒序：最新的对话排最前
    return list.sort((a, b) => b.updateTime - a.updateTime)
  } catch (e) {
    console.error('[ChatPersist] loadSessions failed', JSON.stringify(e))
    return []
  }
}

/** 保存（新增或覆盖）一个会话 */
export function saveSession(ctx: common.UIAbilityContext, session: ChatSession): void {
  try {
    if (session.messages.length === 0) return   // 没有消息的会话不保存

    const store = getStore(ctx)
    const raw = store.getSync(KEY_SESSIONS, '[]') as string
    const list = JSON.parse(raw) as ChatSession[]

    // 如果 id 已存在就覆盖，否则新增
    const idx = list.findIndex(s => s.id === session.id)
    if (idx >= 0) {
      list[idx] = session
    } else {
      list.push(session)
    }

    store.putSync(KEY_SESSIONS, JSON.stringify(list))
    store.flush()   // flush：把内存缓存写入磁盘（异步，不阻塞 UI）
  } catch (e) {
    console.error('[ChatPersist] saveSession failed', JSON.stringify(e))
  }
}

/** 删除单个会话 */
export function deleteSession(ctx: common.UIAbilityContext, sessionId: string): void {
  try {
    const store = getStore(ctx)
    const raw = store.getSync(KEY_SESSIONS, '[]') as string
    const list = (JSON.parse(raw) as ChatSession[]).filter(s => s.id !== sessionId)
    store.putSync(KEY_SESSIONS, JSON.stringify(list))
    store.flush()
  } catch (e) {
    console.error('[ChatPersist] deleteSession failed', JSON.stringify(e))
  }
}
