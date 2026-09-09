import { describe, expect, it } from '@ohos/hypium'
import { ChatSessionController } from '../../../main/ets/controller/ChatSessionController'
import { ChatMessage } from '../../../main/ets/models/chatModel'
import { ChatViewModel } from '../../../main/ets/viewmodel/ChatViewModel'

export default function chatSessionControllerTest(): void {
  describe('ChatSessionControllerTest', () => {
    it('newSessionResetsIdleState', 0, () => {
      const vm = new ChatViewModel()
      const message = new ChatMessage()
      message.id = 'message-1'
      vm.sessionId = 'session-old'
      vm.inputContent = 'draft'
      vm.historyMessage = [message]

      const controller = new ChatSessionController(vm)
      const changed = controller.newSession()

      expect(changed).assertTrue()
      expect(vm.sessionId === 'session-old').assertFalse()
      expect(vm.inputContent).assertEqual('')
      expect(vm.historyMessage.length).assertEqual(0)
    })

    it('newSessionRefusesWhileGenerating', 0, () => {
      const vm = new ChatViewModel()
      const message = new ChatMessage()
      message.id = 'message-1'
      vm.sessionId = 'session-active'
      vm.inputContent = 'draft'
      vm.historyMessage = [message]
      vm.isLoading = true

      const controller = new ChatSessionController(vm)
      const changed = controller.newSession()

      expect(changed).assertFalse()
      expect(vm.sessionId).assertEqual('session-active')
      expect(vm.inputContent).assertEqual('draft')
      expect(vm.historyMessage.length).assertEqual(1)
      expect(vm.isLoading).assertTrue()
    })
  })
}
