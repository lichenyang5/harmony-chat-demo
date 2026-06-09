import { TripCard } from '../models/chatModel'

@ComponentV2
export struct ConfirmTripCardComp {
  // 只用于兼容外部 ConfirmTripCardComp({ card: xxx }) 调用，组件内部不使用
  @Param @Require card: TripCard

  build() {
    Column() {
      // ============ Header 区域 ============
      Stack({ alignContent: Alignment.TopStart }) {
        // Header 底色：品牌蓝
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#FF00B5D9')

        // Header 第一层渐变：左侧白色 -> 右侧透明
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 90,
            colors: [
              ['#FEFFFFFF', 0.0],
              ['#00FFFFFF', 1.0]
            ]
          })

        // Header 第二层渐变：上方半透明白 -> 下方纯白
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [
              ['#B3FFFFFF', 0.0],
              ['#FFFFFFFF', 1.0]
            ]
          })

        // Header 内容层
        Column() {
          // ============ 标题区域 ============
          Stack({ alignContent: Alignment.BottomStart }) {
            Column()
              .width(80)
              .height(8)
              .backgroundColor('#FFFFD91A')
              .borderRadius(8)

            Text('确认行程')
              .fontSize(20)
              .lineHeight(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#E6000000')
          }

          // ============ 行程信息区域：左侧路线轴 + 右侧三行文本 ============
          Row() {
            // ============ 左侧路线轴 ============
            Stack({ alignContent: Alignment.Top }) {
              // 中间虚线：图标间距 36，虚线上下各伸进图标 2，所以总高 40
              Line()
                .width(1)
                .height(40)
                .startPoint([0, 0])
                .endPoint([0, 40])
                .stroke('#4D000000')
                .strokeWidth(1)
                .strokeDashArray([2, 2])
                .offset({ y: 10 })

              // 起点图标：12 * 12
              Image($r('app.media.start'))
                .width(12)
                .height(12)
                .objectFit(ImageFit.Contain)
                .offset({ y: 0 })

              // 终点图标：12 * 12，y = 12 + 36 = 48
              Image($r('app.media.end'))
                .width(12)
                .height(12)
                .objectFit(ImageFit.Contain)
                .offset({ y: 48 })
            }
            .width(12)
            .height(60)

            // ============ 右侧三行文本 ============
            // Stack({ alignContent: Alignment.TopStart }) {
            //   // 起点行
            //   Row() {
            //     Row() {
            //       Text('香港中国企业协会')
            //         .fontSize(12)
            //         .lineHeight(16)
            //         .fontColor('#E6000000')
            //         .maxLines(1)
            //         .textOverflow({ overflow: TextOverflow.Ellipsis })
            //
            //       Image($r('app.media.right'))
            //         .width(6)
            //         .height(12)
            //         .objectFit(ImageFit.Contain)
            //         .margin({ left: 4 })
            //     }
            //     .layoutWeight(1)
            //     .height(16)
            //     .alignItems(VerticalAlign.Center)
            //
            //     Text('立即出发')
            //       .fontSize(10)
            //       .lineHeight(12)
            //       .fontColor('#99000000')
            //       .margin({ left: 8 })
            //   }
            //   .width('100%')
            //   .height(16)
            //   .alignItems(VerticalAlign.Center)
            //   .offset({ y: -2 })
            //
            //   // 距离 / 时长行
            //   Row() {
            //     Row() {
            //       Image($r('app.media.jiange'))
            //         .width(12)
            //         .height(12)
            //         .objectFit(ImageFit.Contain)
            //
            //       Text('全程34.2公里')
            //         .fontSize(10)
            //         .lineHeight(12)
            //         .fontColor('#99000000')
            //         .margin({ left: 4 })
            //     }
            //     .layoutWeight(1)
            //     .height(12)
            //     .alignItems(VerticalAlign.Center)
            //
            //     Row() {
            //       Image($r('app.media.time'))
            //         .width(12)
            //         .height(12)
            //         .objectFit(ImageFit.Contain)
            //
            //       Text('45分钟')
            //         .fontSize(10)
            //         .lineHeight(12)
            //         .fontColor('#66000000')
            //         .margin({ left: 4 })
            //     }
            //     .height(12)
            //     .alignItems(VerticalAlign.Center)
            //   }
            //   .width('100%')
            //   .height(12)
            //   .alignItems(VerticalAlign.Center)
            //   .offset({ y: 24 })
            //
            //   // 终点行
            //   Row() {
            //     Row() {
            //       Text('香港国际机场')
            //         .fontSize(12)
            //         .lineHeight(16)
            //         .fontColor('#E6000000')
            //         .maxLines(1)
            //         .textOverflow({ overflow: TextOverflow.Ellipsis })
            //
            //       Image($r('app.media.right'))
            //         .width(6)
            //         .height(12)
            //         .objectFit(ImageFit.Contain)
            //         .margin({ left: 4 })
            //     }
            //     .layoutWeight(1)
            //     .height(16)
            //     .alignItems(VerticalAlign.Center)
            //
            //     Text('预计13:30到达')
            //       .fontSize(10)
            //       .lineHeight(12)
            //       .fontColor('#66000000')
            //   }
            //   .width('100%')
            //   .height(16)
            //   .alignItems(VerticalAlign.Center)
            //   .offset({ y: 46 })
            // }
            // .width('100%')
            // .height(60)
            // .layoutWeight(1)
            // .margin({left:4})

            // ============ 右侧三行文本 ============
            Stack({ alignContent: Alignment.TopStart }) {
              // 起点行：中心 y = 6
              Row() {
                Row() {
                  Text('香港中国企业协会')
                    .fontSize(12)
                    .lineHeight(16)
                    .fontColor('#E6000000')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Image($r('app.media.right'))
                    .width(6)
                    .height(12)
                    .objectFit(ImageFit.Contain)
                    .margin({ left: 4 })
                }
                .layoutWeight(1)
                .height(16)
                .alignItems(VerticalAlign.Center)

                Text('立即出发')
                  .fontSize(10)
                  .lineHeight(12)
                  .fontColor('#99000000')
                  .margin({ left: 8 })
              }
              .width('100%')
              .height(16)
              .alignItems(VerticalAlign.Center)
              .offset({ y: -2 })

              // 距离 / 时长行：中心 y = 30
              Row() {
                Row() {
                  Image($r('app.media.jiange'))
                    .width(12)
                    .height(12)
                    .objectFit(ImageFit.Contain)

                  Text('全程34.2公里')
                    .fontSize(10)
                    .lineHeight(12)
                    .fontColor('#99000000')
                    .margin({ left: 4 })
                }
                .layoutWeight(1)
                .height(12)
                .alignItems(VerticalAlign.Center)

                Row() {
                  Image($r('app.media.time'))
                    .width(12)
                    .height(12)
                    .objectFit(ImageFit.Contain)

                  Text('45分钟')
                    .fontSize(10)
                    .lineHeight(12)
                    .fontColor('#66000000')
                    .margin({ left: 4 })
                }
                .height(12)
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .height(12)
              .alignItems(VerticalAlign.Center)
              .offset({ y: 24 })

              // 终点行：中心 y = 54
              Row() {
                Row() {
                  Text('香港国际机场')
                    .fontSize(12)
                    .lineHeight(16)
                    .fontColor('#E6000000')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Image($r('app.media.right'))
                    .width(6)
                    .height(12)
                    .objectFit(ImageFit.Contain)
                    .margin({ left: 4 })
                }
                .layoutWeight(1)
                .height(16)
                .alignItems(VerticalAlign.Center)

                Text('预计13:30到达')
                  .fontSize(10)
                  .lineHeight(12)
                  .fontColor('#66000000')
              }
              .width('100%')
              .height(16)
              .alignItems(VerticalAlign.Center)
              .offset({ y: 46 })
            }
            .width('100%')
            .height(60)
            .margin({left:4})
            .layoutWeight(1)
          }
          .margin({top:24})
          .width('100%')
          .height(60)
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .width(328)
      .height(136)
      .borderRadius({ topLeft: 16, topRight: 16 })
      .clip(true)

      // ============ 票据切割线 / 两侧票根半圆 ============
      Stack({ alignContent: Alignment.Center }) {
        // 中间水平虚线
        Line()
          .height(1)
          .startPoint([0, 0])
          .endPoint([1000, 0])
          .stroke('#1A000000')
          .strokeWidth(1)
          .strokeDashArray([4, 4])
          .width('100%')
          .margin({ left: 12, right: 12 })

        // 左右半圆挖洞
        Row() {
          Circle({ width: 16, height: 16 })
            .fill('#F5F6FA')
            .offset({ x: -8, y: 0 })

          Blank()

          Circle({ width: 16, height: 16 })
            .fill('#F5F6FA')
            .offset({ x: 8, y: 0 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(16)

      // ============ 下方内容区域 ============
      Column() {
        // 地图图片区域
        Image($rawfile('images/1.png'))
          .width(296)
          .height(188)
          .borderRadius(8)

        // 价格 + 选择车型区域
        Row() {
          // 左侧价格文字
          Column() {
            Text('预估145~155人民币起')
              .fontSize(14)
              .lineHeight(18)
              .fontColor('#E6000000')
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .textAlign(TextAlign.Start)

            Text('已选中1种车型:')
              .fontSize(12)
              .lineHeight(16)
              .fontColor('#99000000')
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .width(208)
          .height(34)
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 右侧选择车型按钮
          Button('选择车型')
            .width(80)
            .height(28)
            .backgroundColor('#1A00B5D9')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF00B5D9')
            .borderRadius(8)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }
        .width(296)
        .height(34)
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)

        // 确认用车按钮
        Button('确认用车')
          .width(296)
          .height(40)
          .backgroundColor('#FF00B5D9')
          .fontColor('#FFFFFFFF')
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .borderRadius(8)
          .padding({ left: 116, right: 116, top: 12, bottom: 12 })
          .margin({ top: 24 })
      }
      .width(328)
      .height(318)
      .padding({ left: 16, top: 8, right: 16, bottom: 16 })
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })
    }
    // ============ 整体卡片样式 ============
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({
      radius: 24,
      color: '#10000000',
      offsetX: 0,
      offsetY: 6
    })
    .clip(true)
    .constraintSize({ maxWidth: '92%' })
  }
}