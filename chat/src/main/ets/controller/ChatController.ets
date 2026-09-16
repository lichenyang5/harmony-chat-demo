import { LogUtil } from 'common'
import { ChatMessage, ChatHistoryItem } from '../models/chatModel'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { MessageStatus } from '../models/MessageStatus'
import { ChatRole } from '../constants/ChatConstants'
import { ChatStreamStateMachine } from './ChatStreamStateMachine'

const TAG: string = 'ChatController'

/**
 * 聊天用户操作门面。
 *
 * 本类负责发送、重发和重新生成前的目标校验、消息准备与历史快照；单次 HTTP
 * 请求、SSE 回调、停止和终态收尾统一交给 ChatStreamStateMachine。组件因此
 * 仍只依赖四个稳定入口，不需要了解流式请求的内部状态。
 */
export class ChatController {
  private vm: ChatViewModel
  /** 流式请求的唯一运行时所有者。 */
  private streamStateMachine: ChatStreamStateMachine
  /** 保证同毫秒创建的消息也拥有稳定且唯一的 ForEach key。 */
  private idSeed: number = 0

  constructor(vm: ChatViewModel) {
    this.vm = vm
    this.streamStateMachine = new ChatStreamStateMachine(vm)
  }

  /** 发送输入框内容；输入为空或已有请求在生成时忽略。 */
  sendMessage(): void {
    const content = this.vm.inputContent.trim()
    if (!content || this.vm.isLoading) {
      return
    }
    LogUtil.iPrivate(TAG, '用户发送: %{private}s', content)

    if (!this.vm.sessionId) {
      this.vm.sessionId = Date.now().toString()
    }

    const userMessage = this.createMessage(ChatRole.USER, content, MessageStatus.SENDING)
    const aiMessage = this.createMessage(ChatRole.ASSISTANT, '', MessageStatus.THINKING)

    // 必须在 push 本轮消息前快照，避免把用户消息和空 AI 占位重复带入上下文。
    const history = this.buildHistorySnapshot(this.vm.historyMessage.length)
    this.vm.historyMessage.push(userMessage)
    this.vm.historyMessage.push(aiMessage)
    this.vm.inputContent = ''

    this.streamStateMachine.start(userMessage, aiMessage, history, true)
  }

  /**
   * 重新发送失败的用户消息。复用原 user 对象，只在其后插入新的 AI 占位，
   * 从源头避免重复用户气泡。
   */
  resendMessage(target: ChatMessage): void {
    if (this.vm.isLoading || !target || target.role !== ChatRole.USER) {
      return
    }
    const idx = this.vm.historyMessage.indexOf(target)
    const content = target.content ? target.content : ''
    if (idx < 0 || content.length === 0) {
      return
    }

    const history = this.buildHistorySnapshot(idx)
    target.status = MessageStatus.SENDING
    target.errorHint = ''

    const aiMessage = this.createMessage(ChatRole.ASSISTANT, '', MessageStatus.THINKING)
    this.vm.historyMessage.splice(idx + 1, 0, aiMessage)
    this.streamStateMachine.start(target, aiMessage, history, true)
  }

  /**
   * 重新生成目标 AI 消息。复用原 AI 气泡，并取它前方最近的用户消息作为 prompt；
   * 找不到有效 prompt 或正在生成时忽略。
   */
  regenerate(target: ChatMessage): void {
    if (this.vm.isLoading || !target || target.role !== ChatRole.ASSISTANT) {
      return
    }
    const aiIdx = this.vm.historyMessage.indexOf(target)
    if (aiIdx < 0) {
      return
    }

    let promptIdx = -1
    for (let i = aiIdx - 1; i >= 0; i--) {
      if (this.vm.historyMessage[i].role === ChatRole.USER) {
        promptIdx = i
        break
      }
    }
    if (promptIdx < 0) {
      return
    }

    const promptMsg = this.vm.historyMessage[promptIdx]
    const content = promptMsg.content ? promptMsg.content : ''
    if (content.length === 0) {
      return
    }

    const history = this.buildHistorySnapshot(promptIdx)
    target.content = ''
    target.card = null
    target.status = MessageStatus.THINKING
    target.errorHint = ''
    promptMsg.status = MessageStatus.DONE

    // 重新生成失败时保留 AI 气泡为 FAILED，不把已送达的用户消息改成可重发。
    this.streamStateMachine.start(promptMsg, target, history, false)
  }

  /** 停止当前生成；无在途请求时由状态机安全忽略。 */
  stopGeneration(): void {
    this.streamStateMachine.stop()
  }

  /** 创建响应式消息并生成稳定唯一 ID。 */
  private createMessage(role: ChatRole, content: string, status: MessageStatus): ChatMessage {
    const msg = new ChatMessage()
    const now = Date.now()
    this.idSeed++
    msg.id = `${now}_${role}_${this.idSeed}`
    msg.role = role
    msg.content = content
    msg.createTime = now
    msg.sessionId = this.vm.sessionId
    msg.status = status
    return msg
  }

  /**
   * 构造 [0, endExclusive) 内非空消息的后端上下文快照。
   * 对历史脏数据做空值防御，不把卡片占位或空字符串发送给后端。
   */
  private buildHistorySnapshot(endExclusive: number): ChatHistoryItem[] {
    const result: ChatHistoryItem[] = []
    const end = Math.min(endExclusive, this.vm.historyMessage.length)
    for (let i = 0; i < end; i++) {
      const message = this.vm.historyMessage[i]
      const safeContent = message.content ? message.content : ''
      if (safeContent.length === 0) {
        continue
      }
      const item = new ChatHistoryItem()
      item.role = message.role ? message.role : ChatRole.ASSISTANT
      item.content = safeContent
      result.push(item)
    }
    return result
  }
}
