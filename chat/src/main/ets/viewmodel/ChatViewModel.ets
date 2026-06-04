import { ChatMessage } from '../models/chatModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = ''
  @Trace historyMessage: ChatMessage[] = []

  // 是否正在等待 / 生成 AI 回复
  @Trace isLoading: boolean = false

  // 当前会话 ID
  @Trace sessionId: string = ''

  /**
   * 新建会话时统一重置
   */
  resetForNewSession(): void {
    this.sessionId = Date.now().toString()
    this.historyMessage = []
    this.inputContent = ''
    this.isLoading = false
  }

  /**
   * 加载历史会话后，只清理运行时状态
   */
  resetRuntimeState(): void {
    this.inputContent = ''
    this.isLoading = false
  }
}