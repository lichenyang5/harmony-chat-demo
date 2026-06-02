@ComponentV2
export struct ChatInputComp {
  @Param inputContent: string = ''
  @Event onInputChange: (val: string) => void = () => {}
  @Event onSend: () => void = () => {}

  build() {
    Row({ space: 12 }) {
      TextInput({ placeholder: '说点什么...', text: this.inputContent })
        .onChange((val: string) => { this.onInputChange(val) })
        .layoutWeight(1)
        .backgroundColor('#F5F5F5')
        .borderRadius(20)
        .padding({ left: 16, right: 16 })

      Button('发送')
        .onClick(() => { this.onSend() })
        .enabled(this.inputContent.trim().length > 0)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
  }
}
