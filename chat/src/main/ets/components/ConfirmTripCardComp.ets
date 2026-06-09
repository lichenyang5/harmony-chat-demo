import { ThemeState, getThemeState } from 'common'
import { TripCard } from '../models/chatModel'

/**
 * 确认行程卡片
 *
 * 结构（票据风格，Header 与图标用法完全对齐 PickupConfirmCardComp）：
 *   Column (整体白底, borderRadius 16, clip true)
 *   ├── Header Column   linearGradient 右上蓝→左下白（仅 header）
 *   │   ├── Stack       标题「确认行程」+ 黄色色条(宽度跟随标题字数)
 *   │   └── Row         LeftAxis(起点-虚线-距离-虚线-终点) + 右侧三行文字
 *   ├── TicketDivider   @Builder：水平虚线 + 左右半圆挖洞
 *   ├── Image           地图占位（rawfile 商品图临时复用）
 *   ├── Row             价格  +  [选择车型]
 *   ├── Text            已选中 1 种车型:
 *   └── Button          确认用车
 */
@ComponentV2
export struct ConfirmTripCardComp {
  @Param @Require card: TripCard

  @Local theme: ThemeState = getThemeState()

  // 票据凹口直径
  private static readonly NOTCH_D: number = 14

  // 左轴每段高度（图标 / 虚线 / 图标 / 虚线 / 图标 共 5 段）
  private static readonly AXIS_SEG: number = 14

  // 标题字号
  private static readonly TITLE_FS: number = 22

  // 黄色色条宽度：每个中文字宽 ≈ fontSize
  private titleStripWidth(): number {
    return this.card.title.length * ConfirmTripCardComp.TITLE_FS + 4
  }

  // ───────────── @Builder：票据切割线（水平虚线 + 左右半圆挖洞） ─────────────
  @Builder
  TicketDivider() {
    Stack({ alignContent: Alignment.Center }) {
      Line()
        .height(1)
        .startPoint([0, 0])
        .endPoint([1000, 0])
        .stroke(this.theme.divider)
        .strokeWidth(1)
        .strokeDashArray([4, 4])
        .width('100%')
        .margin({ left: 12, right: 12 })

      Row() {
        Circle({ width: ConfirmTripCardComp.NOTCH_D, height: ConfirmTripCardComp.NOTCH_D })
          .fill(this.theme.bg)
          .offset({ x: -ConfirmTripCardComp.NOTCH_D / 2, y: 0 })

        Blank()

        Circle({ width: ConfirmTripCardComp.NOTCH_D, height: ConfirmTripCardComp.NOTCH_D })
          .fill(this.theme.bg)
          .offset({ x: ConfirmTripCardComp.NOTCH_D / 2, y: 0 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(ConfirmTripCardComp.NOTCH_D)
  }

  // ───────────── @Builder：左侧轴（起点 - 长虚线 - 终点） ─────────────
  // 中间距离/时间行的图标不再在轴上，而是作为普通图标放到文字左侧；
  // 轴在中间行那段就是一段连续虚线，不被打断。
  @Builder
  LeftAxis() {
    Column() {
      // 起点：定位图
      Image($r('app.media.location'))
        .width(ConfirmTripCardComp.AXIS_SEG)
        .height(ConfirmTripCardComp.AXIS_SEG)
        .objectFit(ImageFit.Contain)

      // 起点 → 终点 长虚线（跨越 Blank + 中间行 + Blank 共 3 段 = 42vp）
      Line()
        .width(1)
        .height(ConfirmTripCardComp.AXIS_SEG * 3)
        .startPoint([0, 0])
        .endPoint([0, ConfirmTripCardComp.AXIS_SEG * 3])
        .stroke(this.theme.textTertiary)
        .strokeWidth(1)
        .strokeDashArray([2, 2])

      // 终点：定位图
      Image($r('app.media.location'))
        .width(ConfirmTripCardComp.AXIS_SEG)
        .height(ConfirmTripCardComp.AXIS_SEG)
        .objectFit(ImageFit.Contain)
    }
    .width(ConfirmTripCardComp.AXIS_SEG)
    .alignItems(HorizontalAlign.Center)
  }

  // ───────────── build ─────────────
  build() {
    Column() {
      // ============ Header（双层叠加渐变：底层 angle:90 白→浅青蓝；上层 angle:180 透明→白柔化） ============
      Stack({ alignContent: Alignment.TopStart }) {
        // 背景层：左白 -> 右蓝（横向）
        Column()
          .width('100%')
          .height(140)
          .linearGradient({
            angle: 90,
            colors: [
              ['#FFFFFFFF', 0.0],
              ['#FFFFFFFF', 0.03],
              ['#FFF2FCFF', 0.35],
              ['#FFDDF8FF', 1.0]
            ]
          })

        // 内容层：顶部透明（露出底层渐变） -> 底部纯白（衔接切割线下方）
        Column({ space: 14 }) {
          // 标题 + 黄色色条
          Stack({ alignContent: Alignment.BottomStart }) {
            Column()
              .width(this.titleStripWidth())
              .height(10)
              .backgroundColor('#FFEB7A')

            Text(this.card.title)
              .fontSize(ConfirmTripCardComp.TITLE_FS)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
          }

          // 左轴 + 右文字三行（左轴 5 段 70vp，右侧 Column 同高 SpaceBetween 三行）
          Row({ space: 10 }) {
            this.LeftAxis()

            Column() {
              // 起点行
              Row() {
                Text(this.card.startLocation + ' >')
                  .fontSize(13)
                  .fontColor(this.theme.textPrimary)
                  .layoutWeight(1)
                Text(this.card.startTag)
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
              }
              .width('100%')
              .height(ConfirmTripCardComp.AXIS_SEG)
              .alignItems(VerticalAlign.Center)

              Blank().height(ConfirmTripCardComp.AXIS_SEG)

              // 距离 / 时长行：图标在文字左侧（不在 LeftAxis 上）
              // TODO: jiange.png / time.png 放进 chat/.../resources/base/media/ 后，
              //       把下面两处 'app.media.location' 改成 'app.media.jiange' / 'app.media.time'
              Row() {
                Image($r('app.media.jiange'))
                  .width(ConfirmTripCardComp.AXIS_SEG)
                  .height(ConfirmTripCardComp.AXIS_SEG)
                  .objectFit(ImageFit.Contain)
                Text(this.card.distance)
                  .fontSize(13)
                  .fontColor(this.theme.textSecondary)
                  .margin({ left: 6 })
                  .layoutWeight(1)
                Image($r('app.media.time'))
                  .width(ConfirmTripCardComp.AXIS_SEG)
                  .height(ConfirmTripCardComp.AXIS_SEG)
                  .objectFit(ImageFit.Contain)
                Text(this.card.duration)
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
                  .margin({ left: 6 })
              }
              .width('100%')
              .height(ConfirmTripCardComp.AXIS_SEG)
              .alignItems(VerticalAlign.Center)

              Blank().height(ConfirmTripCardComp.AXIS_SEG)

              // 终点 / 到达时间行（终点后补上 > 与起点对齐）
              Row() {
                Text(this.card.endLocation + ' >')
                  .fontSize(13)
                  .fontColor(this.theme.textPrimary)
                  .layoutWeight(1)
                Text(this.card.arriveTime)
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
              }
              .width('100%')
              .height(ConfirmTripCardComp.AXIS_SEG)
              .alignItems(VerticalAlign.Center)
            }
            .alignItems(HorizontalAlign.Start)
            .height(ConfirmTripCardComp.AXIS_SEG * 5)
            .justifyContent(FlexAlign.SpaceBetween)
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 20, bottom: 16 })
        .linearGradient({
          angle: 180,
          colors: [
            ['#00FFFFFF', 0.0],
            ['#00FFFFFF', 0.45],
            ['#99FFFFFF', 0.82],
            ['#FFFFFFFF', 1.0]
          ]
        })
      }
      .width('100%')

      // ============ 票据切割线 ============
      this.TicketDivider()

      // ============ 切割线下方：保持不动 ============

      // 地图占位（暂用商品图）
      Image($rawfile('images/1.png'))
        .width('92%')
        .height(160)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .margin({ top: 12 })

   Column(){
     // 价格 + 选择车型
     Row() {
       Column(){
         Text(this.card.priceRange)
           .fontSize(14)
           .fontColor(this.theme.textPrimary)
         // "已选中1种车型:"
         Text(this.card.selectedHint)
           .fontSize(12)
           .fontColor(this.theme.textSecondary)
       }.layoutWeight(1)
       .alignItems(HorizontalAlign.Start)
       Button(this.card.selectCarText)
         .fontSize(12)
         .fontColor('#00B5D9')
         .height(28)
         .padding({ left: 16, right: 16, top: 8, bottom: 8 })
         .backgroundColor('#E0F4FA')
         .borderRadius(8)
     }
     .width('100%')
     .alignItems(VerticalAlign.Center)
     .padding({ left: 20, right: 20, top: 14, bottom: 6 })
   }
      // 确认用车主按钮
      Button(this.card.confirmText)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .width('92%')
        .height(46)
        .backgroundColor('#00B5D9')
        .borderRadius(8)
        .margin({ top: 12, bottom: 16 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .clip(true)
    .constraintSize({ maxWidth: '92%' })
  }
}
