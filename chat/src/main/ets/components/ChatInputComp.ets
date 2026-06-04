import { ThemeState, getThemeState } from 'common'

@ComponentV2
export struct ChatInputComp {
  @Param inputContent: string = ''
  @Event onInputChange: (val: string) => void = () => {}
  @Event onSend: () => void = () => {}

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

      Button('发送')
        .height(40)
        .backgroundColor(this.inputContent.trim().length > 0 ? this.theme.primary : this.theme.disabledBg)
        .fontColor(this.theme.onPrimary)
        .onClick(() => {
          this.onSend()
        })
        .enabled(this.inputContent.trim().length > 0)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 0 })
    .backgroundColor(this.theme.surface)
  }
}