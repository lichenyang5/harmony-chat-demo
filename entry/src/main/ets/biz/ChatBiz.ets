import { ChatMessage } from '../models/chatModel'
import { ChatImp } from '../imp/ChatImp'

export class ChatBiz {
  private imp: ChatImp = new ChatImp()

  sendMessage(content: string, sessionId?: string): Promise<ChatMessage | null> {
    return this.imp.sendMessage(content, sessionId).then((result) => {
      if (result.code === 200) {
        return result.data
      }
      return null
    })
  }
}