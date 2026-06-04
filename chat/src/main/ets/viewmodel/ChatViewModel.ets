import { ChatMessage } from '../models/chatModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = ''
  @Trace historyMessage: ChatMessage[] = []

  // 是否正在等待 AI 第一个 chunk（首字到达后置 false）
  @Trace isLoading: boolean = false

  @Trace sessionId: string = ''
}
