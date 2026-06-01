import { ChatMessage } from '../models/chatModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = ''
  @Trace historyMessage: ChatMessage[] = []
  @Trace isLoading: boolean = false
  @Trace responseMessage: string = ''
  @Trace sessionId: string = ''
}
