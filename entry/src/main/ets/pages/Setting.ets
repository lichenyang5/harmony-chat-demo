import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

import { RouteConstants } from '../constants/RouteConstants'
import { globalTabState } from '../stores/TabState'
import { ChatMessage } from '../models/ChatModel'
import { ChatViewModel } from '../viewmodels/ChatViewModel'
import { ChatController } from '../controllers/ChatController'

@HMRouter({ pageUrl: RouteConstants.SETTING })
@ComponentV2
export struct Setting {
  private listScroller: Scroller = new Scroller()

  @Local viewModel: ChatViewModel = new ChatViewModel()

  private chatController: ChatController = new ChatController(this.viewModel)

  aboutToAppear(): void {
    globalTabState.setCurrentTab(RouteConstants.SETTING)

    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)

    const context = getContext(this) as common.UIAbilityContext

    this.chatController.initAuth(
      context,
      () => {
        HMRouterMgr.replace({
          pageUrl: RouteConstants.LOGIN
        })
      },
      () => {
        this.scrollToBottom()
      }
    )
  }

  aboutToDisappear(): void {
    this.chatController.release()
  }

  scrollToBottom(): void {
    setTimeout(() => {
      this.listScroller.scrollToIndex(this.viewModel.chatList.length)
    }, 50)
  }

  build() {
    Column() {
      this.Header()
      this.MessageList()
      this.InputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }

  @Builder
  Header() {
    Row() {
      Column() {
        Text('聊天 Demo')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')

        if (this.viewModel.userInfo !== null) {
          Text(`当前用户：${this.viewModel.userInfo.nickname}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        } else {
          Text('未登录')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row() {
        Button('清空')
          .height(32)
          .fontSize(14)
          .enabled(this.viewModel.chatList.length > 0 && !this.viewModel.isSending)
          .onClick(() => {
            const context = getContext(this) as common.UIAbilityContext
            this.chatController.clearChatHistory(context)
          })

        Button('退出')
          .height(32)
          .fontSize(14)
          .margin({ left: 8 })
          .enabled(!this.viewModel.isSending)
          .onClick(() => {
            const context = getContext(this) as common.UIAbilityContext

            this.chatController.logout(
              context,
              () => {
                HMRouterMgr.replace({
                  pageUrl: RouteConstants.LOGIN
                })
              }
            )
          })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MessageList() {
    List({ scroller: this.listScroller }) {
      if (this.viewModel.chatList.length === 0) {
        ListItem() {
          Column() {
            Text('暂无聊天记录')
              .fontSize(16)
              .fontColor('#999999')

            Text('输入内容后开始聊天')
              .fontSize(13)
              .fontColor('#BBBBBB')
              .margin({ top: 8 })
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }

      ForEach(this.viewModel.chatList, (item: ChatMessage) => {
        ListItem() {
          Row() {
            if (item.role === 'user') {
              Blank()

              Text(item.content)
                .fontSize(16)
                .fontColor(Color.White)
                .backgroundColor('#1677FF')
                .borderRadius(10)
                .padding({
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: 8
                })
                .constraintSize({
                  maxWidth: '75%'
                })
            } else {
              Text(item.content)
                .fontSize(16)
                .fontColor('#333333')
                .backgroundColor(Color.White)
                .borderRadius(10)
                .padding({
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: 8
                })
                .constraintSize({
                  maxWidth: '75%'
                })

              Blank()
            }
          }
          .width('100%')
          .margin({ bottom: 12 })
          .alignItems(VerticalAlign.Top)
        }
      }, (item: ChatMessage) => this.chatController.getMessageKey(item))

      ListItem() {
        Row() {
          Blank()
        }
        .height(12)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: 12,
      bottom: 12
    })
  }

  @Builder
  InputBar() {
    Row() {
      TextInput({
        placeholder: '请输入内容',
        text: this.viewModel.inputValue
      })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.White)
        .borderRadius(22)
        .padding({
          left: 14,
          right: 14
        })
        .enabled(!this.viewModel.isSending && this.viewModel.isAuthReady)
        .onChange((value: string) => {
          this.viewModel.setInputValue(value)
        })

      Button(this.viewModel.isSending ? '发送中' : '发送')
        .height(44)
        .margin({ left: 10 })
        .enabled(!this.viewModel.isSending && this.viewModel.isAuthReady)
        .onClick(() => {
          const context = getContext(this) as common.UIAbilityContext

          this.chatController.sendMessage(
            context,
            () => {
              this.scrollToBottom()
            }
          )
        })
    }
    .width('100%')
    .height(64)
    .padding({
      left: 12,
      right: 12
    })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }
}