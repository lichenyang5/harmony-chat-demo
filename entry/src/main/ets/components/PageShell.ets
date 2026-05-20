@Builder
function EmptyBuilder() {
}

@ComponentV2
export struct PageShell {
  @Param title: string = ''
  @Param from: string = ''

  @BuilderParam leftBuilder: () => void = EmptyBuilder
  @BuilderParam contentBuilder: () => void = EmptyBuilder

  build() {
    Column() {
      Row() {
        this.leftBuilder()

        Column() {
          // Text(this.title)
          //   .fontSize(20)
          //   .fontWeight(FontWeight.Bold)
          //
          // Text(`来自：${this.from}`)
          //   .fontSize(12)
          //   .fontColor('#666666')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      // .backgroundColor('#F7F7F7')

      this.contentBuilder()
    }
    .width('100%')
    .height('100%')
  }
}