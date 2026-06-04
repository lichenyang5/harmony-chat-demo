import { ThemeState, getThemeState } from 'common'

@ComponentV2
export struct ChatInputComp {
  @Param inputContent: string = ''
  // 新增：AI 是否正在生成中（true = 显示停止按钮，false = 显示发送按钮）
  @Param isGenerating: boolean = false

  @Event onInputChange: (val: string) => void = () => {}
  @Event onSend: () => void = () => {}
  @Event onStop: () => void = () => {}    // 新增

  @Local theme: ThemeState = getThemeState()

  build() {
    Row({ space: 12 }) {
      TextInput({
        placeholder: '说点什么...',
        text: this.inputContent
      })
        .onChange((val: string) => {
          this.onInputChange(val)
        })
        .layoutWeight(1)
        .height(40)
        .fontColor(this.theme.inputText)
        .placeholderColor(this.theme.placeholderText)
        .backgroundColor(this.theme.inputBg)
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .enabled(!this.isGenerating)   // 生成中禁用输入框

      // 根据状态切按钮
      if (this.isGenerating) {
        // 停止按钮
        Button('停止')
          .height(40)
          .backgroundColor(this.theme.danger)
          .fontColor(this.theme.onDanger)
          .onClick(() => {
            this.onStop()
          })
      } else {
        // 发送按钮
        Button('发送')
          .height(40)
          .backgroundColor(this.inputContent.trim().length > 0 ? this.theme.primary : this.theme.disabledBg)
          .fontColor(this.theme.onPrimary)
          .onClick(() => {
            this.onSend()
          })
          .enabled(this.inputContent.trim().length > 0)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 0 })
    .backgroundColor(this.theme.surface)
  }
}
