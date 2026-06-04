@ComponentV2
export struct ChatInputComp {
  @Param inputContent: string = ''
  @Param isGenerating: boolean = false

  @Event onInputChange: (val: string) => void = () => {}
  @Event onSend: () => void = () => {}
  @Event onStop: () => void = () => {}

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
        .backgroundColor('#F5F5F5')
        .borderRadius(20)
        .padding({ left: 16, right: 16 })

      Button(this.isGenerating ? '停止' : '发送')
        .onClick(() => {
          if (this.isGenerating) {
            this.onStop()
          } else {
            this.onSend()
          }
        })
        .enabled(this.isGenerating || this.inputContent.trim().length > 0)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 0 })
    .backgroundColor('#FFFFFF')
  }
}