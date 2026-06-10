import { TripCard } from '../models/chatModel'
import { PathShape } from '@kit.ArkUI'

@ComponentV2
export struct ConfirmTripCardComp {
  @Param @Require card: TripCard

  @Local cardWidth: number = 0     // px
  @Local cardHeight: number = 0    // px
  @Local notchY: number = 0        // 缺口中心 y, px
  @Local headerH: number = 0       // 抬头区高, vp

  private readonly cornerRadius: number = 16
  private readonly notchRadius: number = 9

  getCardPath(): string {
    const w = this.cardWidth
    const h = this.cardHeight
    if (w <= 0 || h <= 0) {
      return 'M0 0 L2000 0 L2000 2000 L0 2000 Z'
    }
    const r = vp2px(this.cornerRadius)
    const nr = vp2px(this.notchRadius)
    const minNy = r + nr
    const maxNy = h - r - nr
    if (maxNy <= minNy) {
      return `M ${r} 0 H ${w - r} A ${r} ${r} 0 0 1 ${w} ${r}`
        + ` V ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h}`
        + ` H ${r} A ${r} ${r} 0 0 1 0 ${h - r}`
        + ` V ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
    }
    let ny = this.notchY > nr ? this.notchY : h / 2
    if (ny < minNy) ny = minNy
    if (ny > maxNy) ny = maxNy
    return `M ${r} 0`
      + ` H ${w - r} A ${r} ${r} 0 0 1 ${w} ${r}`
      + ` V ${ny - nr} A ${nr} ${nr} 0 0 0 ${w} ${ny + nr}`
      + ` V ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h}`
      + ` H ${r} A ${r} ${r} 0 0 1 0 ${h - r}`
      + ` V ${ny + nr} A ${nr} ${nr} 0 0 0 0 ${ny - nr}`
      + ` V ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // ============ 抬头区 ============
        this.TicketHeader()

        // ============ 撕线：高 0 + top dashed，clipShape 自动裁到缺口之间 ============
        Row()
          .width('100%')
          .height(0)
          .border({
            width: { top: 1 },
            color: '#1A000000',
            style: BorderStyle.Dashed
          })

        // ============ 白色区 ============
        Column() {
          Image($rawfile('images/1.png'))
            .width('100%')
            .height(188)
            .borderRadius(8)
            .draggable(false)
          Row({ space: 8 }) {
            Column() {
              Text(this.card.priceRange)
                .fontSize(14)
                .lineHeight(18)
                .fontColor('#E6000000')
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .textAlign(TextAlign.Start)

              Text(this.card.selectedHint)
                .fontSize(12)
                .lineHeight(16)
                .fontColor('#99000000')
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(this.card.selectCarText)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FF00B5D9')
              .backgroundColor('#1A00B5D9')
              .borderRadius(8)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }
          .margin({ top: 8, bottom: 24 })
          .width('100%')

          Text(this.card.confirmText)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .backgroundColor('#FF00B5D9')
            .borderRadius(8)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor(Color.White)
      }
      .width('100%')
      .backgroundColor(Color.White)
      // 关键 1：先裁形状
      .clipShape(new PathShape({ commands: this.getCardPath() }))
      // 关键 2：后加阴影 → 沿凹陷轮廓自动外发光
      .shadow({
        radius: 14,
        color: '#22000000',
        offsetX: 0,
        offsetY: 6
      })
      // 关键 3：测真实尺寸 → 重算 path
      .onAreaChange((_o: Area, n: Area) => {
        this.cardWidth = vp2px(Number(n.width))
        this.cardHeight = vp2px(Number(n.height))
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: '92%' })
  }

  @Builder
  TicketHeader() {
    Stack() {
      // 背景层：蓝底 + 横向白→透
      Column()
        .width('100%')
        .height(this.headerH)
        .backgroundColor('#FF00B5D9')
        .linearGradient({
          angle: 90,
          colors: [['#FFFFFFFF', 0.0], ['#00FFFFFF', 1.0]]
        })

      // 内容层 + 纵向半透明白→白
      Column({ space: 20 }) {
        // 标题 + 黄色下划线
        Stack({ alignContent: Alignment.BottomStart }) {
          Row()
            .width(84)
            .height(8)
            .backgroundColor('#FFD91A')
            .borderRadius(4)

          Text(this.card.title)
            .fontSize(20)
            .lineHeight(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E6000000')
        }

        Column() {
          // 起点行
          Row({ space: 4 }) {
            Image($r('app.media.start')).width(12).height(12)
            Row({ space: 4 }) {
              Text(this.card.startLocation)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#E6000000')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Image($r('app.media.right')).width(6).height(12)
            }
            .layoutWeight(1)
            Text(this.card.startTag)
              .fontSize(10).lineHeight(12).fontColor('#99000000')
          }
          .width('100%').alignItems(VerticalAlign.Center)

          // 中间行：左侧竖虚线 + 全程/时长信息
          Row() {
            Column() {
              Line()
                .width(1).height(32)
                .startPoint([0, 0]).endPoint([0, 32])
                .stroke('#B5BAC4').strokeWidth(1)
                .strokeDashArray([2, 2])
            }
            .width(12).margin({ right: 8 })
            .alignItems(HorizontalAlign.Center)

            Image($r('app.media.jiange')).width(12).height(12)
            Text(this.card.distance)
              .fontSize(10).lineHeight(12).fontColor('#99000000')
              .margin({ left: 4 })

            Blank()

            Image($r('app.media.time')).width(12).height(12)
            Text(this.card.duration)
              .fontSize(10).lineHeight(12).fontColor('#66000000')
              .margin({ left: 4 })
          }
          .width('100%').alignItems(VerticalAlign.Center)

          // 终点行
          Row({ space: 4 }) {
            Image($r('app.media.end')).width(12).height(12)
            Row({ space: 4 }) {
              Text(this.card.endLocation)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#E6000000')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Image($r('app.media.right')).width(6).height(12)
            }
            .layoutWeight(1)
            Text(this.card.arriveTime)
              .fontSize(10).lineHeight(12).fontColor('#66000000')
          }
          .width('100%').alignItems(VerticalAlign.Center)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })
      .linearGradient({
        angle: 180,
        colors: [['#B3FFFFFF', 0.0], ['#FFFFFFFF', 1.0]]
      })
      // 关键 4：测抬头高 → 缺口中线就贴在抬头底边
      .onAreaChange((_o: Area, n: Area) => {
        this.headerH = Number(n.height)
        this.notchY = vp2px(Number(n.height))
      })
    }
    .width('100%')
  }
}