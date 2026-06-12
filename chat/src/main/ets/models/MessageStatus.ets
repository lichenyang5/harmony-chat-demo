/**
 * 消息状态机
 *
 * 一条消息在任意时刻只处于一个状态。用单一枚举而不是多个 boolean
 * （isLoading / isStreaming / isFailed），从类型上杜绝
 * “isLoading && isFailed” 这类自相矛盾的非法组合（illegal states unrepresentable）。
 *
 * 状态流转：
 *   用户消息:  SENDING ──► DONE      （请求被服务端受理）
 *                     └──► FAILED    （发不出去，可重新发送）
 *
 *   AI 消息:   THINKING ─► STREAMING ─► DONE      （正常收完）
 *                      │            ├─► STOPPED   （用户中途停止）
 *                      │            └─► FAILED    （中途断网，留部分内容，可重新生成）
 *                      └─► FAILED                 （一个 token 都没来）
 */
export enum MessageStatus {
  /** 用户消息：已加入列表，等待请求被服务端受理（首个 chunk / done 之前） */
  SENDING = 'sending',
  /** AI 消息：请求已受理，等待首个 token（“思考中”） */
  THINKING = 'thinking',
  /** AI 消息：正在逐字输出 */
  STREAMING = 'streaming',
  /** 终态：正常完成 */
  DONE = 'done',
  /** 终态：用户主动停止生成 */
  STOPPED = 'stopped',
  /** 终态：失败（user → 可重新发送；assistant → 可重新生成） */
  FAILED = 'failed',
}

/**
 * 是否为终态：不会再自行变化，只能由用户操作（重发 / 重新生成）触发新一轮。
 *
 * 持久化读回时用它判断“中途态需要归一化”——
 * App 被杀后流不可能续上，读回的 SENDING/THINKING/STREAMING 必须改写成 FAILED。
 */
export function isTerminal(status: MessageStatus): boolean {
  return status === MessageStatus.DONE
    || status === MessageStatus.STOPPED
    || status === MessageStatus.FAILED
}
