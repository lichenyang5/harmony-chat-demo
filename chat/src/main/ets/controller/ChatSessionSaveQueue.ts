export type ChatSessionSaveTask = () => Promise<void>
export type ChatSessionSaveStateListener = (pending: boolean) => void

/**
 * 会话保存任务的轻量 FIFO 队列。
 *
 * 队列只管理 Promise 顺序和待处理计数，不读取 ChatViewModel，也不知道 RDB、
 * UIAbilityContext 或抽屉状态。页面仍拥有响应式 busy 状态和具体保存动作。
 */
export class ChatSessionSaveQueue {
  /** 始终会恢复为 fulfilled，确保前一次失败不会阻断后续保存。 */
  private tail: Promise<void> = Promise.resolve()
  /** 已入队但尚未结束的任务数，用于只在忙闲边界通知页面。 */
  private pendingCount: number = 0

  /**
   * 将保存任务追加到队尾。
   *
   * 返回给调用者的 Promise 保留任务失败，便于页面记录或提示；内部 tail 则
   * 捕获并记录失败，恢复成 fulfilled 后继续下一项。这两个 Promise 分别服务于
   * “错误可见”与“队列不中断”，不能合并为同一个错误语义。
   */
  enqueue(
    task: ChatSessionSaveTask,
    onPendingChange: ChatSessionSaveStateListener
  ): Promise<void> {
    this.pendingCount++
    if (this.pendingCount === 1) {
      onPendingChange(true)
    }

    const current = this.tail
      .then(() => task())
      .finally(() => {
        this.pendingCount--
        if (this.pendingCount === 0) {
          onPendingChange(false)
        }
      })

    this.tail = current.catch((error: Object) => {
      // 保持本文件为纯 TS，避免从 TS 反向导入 ArkTS 日志模块。
      console.error('ChatSessionSaveQueue: save task failed; queue will continue: ' + JSON.stringify(error))
    })
    return current
  }
}
