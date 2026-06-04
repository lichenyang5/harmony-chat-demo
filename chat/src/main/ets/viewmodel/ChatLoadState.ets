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
 * 流程：
 *   ChatHistoryPage 点击 → 设 pendingSessionId = xxx → pop 回首页
 *   ↓
 *   HomePage @Monitor pendingSessionId → 切到 Chat Tab（index = 1）
 *   ChatTabComp @Monitor pendingSessionId → loadSession + 清空 pendingSessionId
 */
@ObservedV2
export class ChatLoadState {
  @Trace pendingSessionId: string = ''
}

export function getChatLoadState(): ChatLoadState {
  return AppStorageV2.connect(ChatLoadState, 'ChatLoadState', () => new ChatLoadState())!
}
