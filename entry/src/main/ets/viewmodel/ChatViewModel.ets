import { ChatMessage } from '../models/chatModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = ''
  @Trace historyMessage: ChatMessage[] = []
  @Trace isLoading: boolean = false
  @Trace pendingResponse: string = ''  // controller 收到响应后设置，组件消费后清空
  @Trace sessionId: string = ''
}
