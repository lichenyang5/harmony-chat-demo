import { ChatBiz } from '../biz/ChatBiz'
import { ChatMessage } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'

export class ChatController {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  sendMessage(): void {
    const content = this.vm.inputContent.trim()
    if (!content) {
      return
    }

    // 1. 用户消息推入历史记录
    const userMessage = new ChatMessage()
    userMessage.id = Date.now().toString()
    userMessage.role = 'user'
    userMessage.content = content
    userMessage.createTime = Date.now()
    this.vm.historyMessage.push(userMessage)

    // 2. 清空输入框
    this.vm.inputContent = ''

    // 3. 显示 AI 加载气泡
    this.vm.isLoading = true

    // 4. 调 Biz 获取响应
    this.biz.sendMessage(content, this.vm.sessionId || undefined)
      .then((result) => {
        this.vm.isLoading = false

        if (!result) {
          return
        }

        // 5. 更新 sessionId
        this.vm.sessionId = result.sessionId

        // 6. 打字机效果输出响应内容
        const fullText = result.content
        let index = 0
        const timer = setInterval(() => {
          this.vm.responseMessage += fullText[index]
          index++
          if (index >= fullText.length) {
            clearInterval(timer)

            // 7. 打完后推入历史记录，清空临时响应
            const aiMessage = new ChatMessage()
            aiMessage.id = result.id
            aiMessage.role = 'assistant'
            aiMessage.content = fullText
            aiMessage.createTime = result.createTime
            this.vm.historyMessage.push(aiMessage)
            this.vm.responseMessage = ''
          }
        }, 30)
      })
      .catch(() => {
        this.vm.isLoading = false
      })
  }
}
