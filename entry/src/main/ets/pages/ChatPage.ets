import { HMRouter } from '@hadss/hmrouter'
import { HMUtil } from '../utils/HMUtil'
import { ChatController } from '../controller/ChatController'
import { ChatViewModel } from '../viewmodel/ChatViewModel'
import { ChatListComp } from '../components/ChatListComp'
import { ChatInputComp } from '../components/ChatInputComp'

@HMRouter({ pageUrl: 'pages/Chat' })
@ComponentV2
export struct ChatPage {
  @Local vm: ChatViewModel = new ChatViewModel()
  @Local controller: ChatController = new ChatController(this.vm)
  @Local showDrawer: boolean = false

  build() {
    // Stack 作为唯一根节点，抽屉叠在内容上方
    Stack({ alignContent: Alignment.TopEnd }) {

      // 主内容区
      Column() {
        // 顶部栏
        Row() {
          Text('←')
            .fontSize(22)
            .padding(8)
            .onClick(() => { HMUtil.pop() })

          Blank()

          Text('AI 助手').fontSize(18).fontWeight(FontWeight.Medium)

          Blank()

          Text('☰')
            .fontSize(22)
            .padding(8)
            .onClick(() => { this.showDrawer = !this.showDrawer })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 8 })

        // 消息列表
        ChatListComp({ vm: this.vm })

        // 底部输入框
        ChatInputComp({
          inputContent: this.vm.inputContent,
          onInputChange: (val: string) => { this.vm.inputContent = val },
          onSend: () => { this.controller.sendMessage() }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      // 历史记录抽屉（叠在右侧）
      if (this.showDrawer) {
        Column() {
          Row() {
            Text('历史记录').fontSize(18).fontWeight(FontWeight.Medium)
            Blank()
            Text('✕')
              .fontSize(18)
              .onClick(() => { this.showDrawer = false })
          }
          .width('100%')
          .padding(16)

          Text('暂无历史记录').fontColor('#999999').padding(16)
        }
        .width('70%')
        .height('100%')
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 8, color: '#33000000', offsetX: -4 })
      }

    }
    .width('100%')
    .height('100%')
  }
}
