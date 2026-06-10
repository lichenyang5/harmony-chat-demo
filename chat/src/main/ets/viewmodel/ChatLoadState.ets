import { AppStorageV2 } from '@kit.ArkUI'

/**
 * 跨页面/跨组件的"待加载会话"信号
 *
 * 使用场景：ChatHistoryPage 是路由页面，ChatTabComp 是 Tab 子组件，
 * 两者无直接父子关系，需要一个全局信号告诉 Chat Tab "请加载这个会话"。
 *
 * 用 AppStorageV2 而不是 PersistenceV2 —— 这是会话级临时信号，
 * App 重启后不需要恢复。
 *
 * 两个信号：
 * 1. pendingSessionId —— "请加载这个会话"
 *    流程：ChatHistoryPage 点击 → 设 pendingSessionId → pop 回首页
 *      → HomePage @Monitor 切到 Chat Tab
 *      → ChatTabComp @Monitor 调 loadSessionById + 清空 pendingSessionId
 *
 * 2. deletedSessionId —— "这个会话刚被删除了"
 *    流程：ChatHistoryPage 左滑删除 → ChatHistoryController.deleteSession
 *      → 设 deletedSessionId
 *      → ChatTabComp @Monitor：若当前正在显示这个会话，重置成新会话；清空信号
 */
@ObservedV2
export class ChatLoadState {
  @Trace pendingSessionId: string = ''
  /** 刚被删除的会话 ID，用于通知 ChatTabComp 重置当前会话 */
  @Trace deletedSessionId: string = ''
}

export function getChatLoadState(): ChatLoadState {
  return AppStorageV2.connect(ChatLoadState, 'ChatLoadState', () => new ChatLoadState())!
}
