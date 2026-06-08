import { ThemeState, getThemeState } from 'common'
import { PickupCard, PickupPoint } from '../models/chatModel'

/**
 * 确认上车点卡片（票据风格）
 *
 * 结构：
 *   Column (整体白底, borderRadius 16, clip true)
 *   ├── Header Column   linearGradient 右上蓝→左下白（仅 header）
 *   │   ├── Stack       标题 + 黄色色条(宽度跟随标题字数)
 *   │   └── Row         左侧轴(?-虚线-📍) + 右侧两行文字
 *   ├── TicketDivider   @Builder：水平虚线 + 左右半圆挖洞
 *   ├── List            上车点；首项含「进站口」按钮 + 三横线图标
 *   └── Footer Column   「查看更多」浅蓝底蓝字按钮
 *
 * 半圆凹口原理：
 *   Circle 在 Row 内通过 .offset({x:±NOTCH_D/2}) 把圆心移到卡片左/右边缘。
 *   外层卡片 .clip(true) 把落在卡片外的半圆裁掉，留下半圆挖洞效果。
 *   圆色 = theme.bg（外部气泡列表背景），与白色卡片对比明显。
 */
@ComponentV2
export struct PickupConfirmCardComp {
  @Param @Require card: PickupCard

  @Local theme: ThemeState = getThemeState()

  // 票据凹口直径
  private static readonly NOTCH_D: number = 14

  // 左轴每段高度（问号 / 虚线 / 地图），三段相加 = 文字两行 + 间隔
  private static readonly AXIS_SEG: number = 14

  // 标题字号
  private static readonly TITLE_FS: number = 22

  // 黄色色条宽度：每个中文字宽 ≈ fontSize，再加少量 padding
  private titleStripWidth(): number {
    return this.card.title.length * PickupConfirmCardComp.TITLE_FS + 4
  }

  // ───────────── @Builder：票据切割线（水平虚线 + 左右半圆挖洞） ─────────────
  @Builder
  TicketDivider() {
    Stack({ alignContent: Alignment.Center }) {
      // 中间水平虚线
      Line()
        .height(1)
        .startPoint([0, 0])
        .endPoint([1000, 0])
        .stroke(this.theme.divider)
        .strokeWidth(1)
        .strokeDashArray([4, 4])
        .width('100%')
        .margin({ left: 12, right: 12 })

      // 左右挖洞：圆心通过 offset 移到卡片左/右边界
      Row() {
        Circle({ width: PickupConfirmCardComp.NOTCH_D, height: PickupConfirmCardComp.NOTCH_D })
          .fill(this.theme.bg)
          .offset({ x: -PickupConfirmCardComp.NOTCH_D / 2, y: 0 })

        Blank()

        Circle({ width: PickupConfirmCardComp.NOTCH_D, height: PickupConfirmCardComp.NOTCH_D })
          .fill(this.theme.bg)
          .offset({ x: PickupConfirmCardComp.NOTCH_D / 2, y: 0 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(PickupConfirmCardComp.NOTCH_D)
  }

  // ───────────── @Builder：左侧轴（问号 - 虚线 - 地图） ─────────────
  @Builder
  LeftAxis() {
    Column() {
      // 问号
      Text('?')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .width(PickupConfirmCardComp.AXIS_SEG)
        .height(PickupConfirmCardComp.AXIS_SEG)
        .textAlign(TextAlign.Center)
        .border({
          width: 1.2,
          color: this.theme.textPrimary,
          radius: PickupConfirmCardComp.AXIS_SEG / 2
        })

      // 纵向虚线
      Line()
        .width(1)
        .height(PickupConfirmCardComp.AXIS_SEG)
        .startPoint([0, 0])
        .endPoint([0, PickupConfirmCardComp.AXIS_SEG])
        .stroke(this.theme.textTertiary)
        .strokeWidth(1)
        .strokeDashArray([2, 2])

      // 地图图标
      Image($r('app.media.location'))
        .width(PickupConfirmCardComp.AXIS_SEG)
        .height(PickupConfirmCardComp.AXIS_SEG)
        .objectFit(ImageFit.Contain)
    }
    .width(PickupConfirmCardComp.AXIS_SEG)
    .alignItems(HorizontalAlign.Center)
  }

  // ───────────── @Builder：列表项 ─────────────
  @Builder
  buildPointItem(p: PickupPoint, isFirst: boolean) {
    Column({ space: 6 }) {
      // 序号 + 名称 + 距离
      Row() {
        Text(p.index.toString())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(20)
          .height(20)
          .textAlign(TextAlign.Center)
          .backgroundColor('#0E5BCC')
          .borderRadius(10)

        Text(p.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)
          .margin({ left: 8 })
          .layoutWeight(1)

        Text(p.distance)
          .fontSize(13)
          .fontColor(this.theme.textSecondary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 地址（左缩进 28 与名称对齐）
      Text(p.address)
        .fontSize(13)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 28 })

      // 首项额外：进站口按钮 + 三横线图标
      if (isFirst && p.entrance) {
        Row({ space: 8 }) {
          Text(p.entrance)
            .fontSize(13)
            .fontColor(this.theme.textPrimary)
            .layoutWeight(1)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .border({ width: 1, color: this.theme.divider })

          Column({ space: 3 }) {
            Row().width(14).height(2).backgroundColor(this.theme.textSecondary).borderRadius(1)
            Row().width(14).height(2).backgroundColor(this.theme.textSecondary).borderRadius(1)
            Row().width(14).height(2).backgroundColor(this.theme.textSecondary).borderRadius(1)
          }
          .width(32)
          .height(32)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .border({ width: 1, color: this.theme.divider })
        }
        .margin({ left: 28, top: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10 })
  }

  // ───────────── build ─────────────
  build() {
    Column() {
      // ============ Header（仅 header 内做渐变：右上蓝 → 左下白，底部变白） ============
      Stack({ alignContent: Alignment.TopStart }) {
        // 背景层：左白 -> 右蓝
        Column()
          .width('100%')
          .height(112)
          .linearGradient({
            angle: 90,
            colors: [
              ['#FFFFFFFF', 0.0],
              ['#FFFFFFFF', 0.03],
              ['#FFF2FCFF', 0.35],
              ['#FFDDF8FF', 1.0]
            ]
          })

        // 内容层：底部渐变白
        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Column()
              .width(this.titleStripWidth())
              .height(10)
              .backgroundColor('#FFEB7A')

            Text(this.card.title)
              .fontSize(PickupConfirmCardComp.TITLE_FS)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
          }

          Row({ space: 10 }) {
            this.LeftAxis()

            Column() {
              Text(this.card.question)
                .fontSize(13)
                .fontColor(this.theme.textPrimary)
                .height(PickupConfirmCardComp.AXIS_SEG)

              Blank().height(PickupConfirmCardComp.AXIS_SEG)

              Text(this.card.currentLocation)
                .fontSize(13)
                .fontColor(this.theme.textPrimary)
                .height(PickupConfirmCardComp.AXIS_SEG)
            }
            .alignItems(HorizontalAlign.Start)
            .height(PickupConfirmCardComp.AXIS_SEG * 3)
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .alignItems(VerticalAlign.Top)
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

      // ============ List：上车点 ============
      List({ space: 4 }) {
        ForEach(this.card.points, (p: PickupPoint, idx: number) => {
          ListItem() {
            this.buildPointItem(p, idx === 0)
          }
        }, (p: PickupPoint) => p.index + '_' + p.name)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })

      // ============ Footer：查看更多按钮（浅蓝底蓝字） ============
      Column() {
        Text(this.card.moreText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.primary)
          .width('100%')
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E6F0FF')
          .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .clip(true)
    .constraintSize({ maxWidth: '92%' })
  }
}
