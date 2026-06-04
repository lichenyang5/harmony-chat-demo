import { ChatMessage } from '../models/chatModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = ''
  @Trace historyMessage: ChatMessage[] = []

  // 是否正在等待 AI 回复（含网络往返 + 流式输出全程）
  @Trace isLoading: boolean = false

  // 当前正在流式生成的 AI 内容（每收到一个 chunk 追加到这里）
  // 流结束时把它转成 ChatMessage 推入 historyMessage，再清空
  @Trace streamingContent: string = ''

  @Trace sessionId: string = ''
}
