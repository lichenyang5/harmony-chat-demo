import { PickupCard, PickupPoint } from '../models/chatModel'
import { PathShape } from '@kit.ArkUI'
import { ThemeState, getThemeState } from 'common'

/**
 * 确认上车点卡片（票根风格 — 数据驱动版）
 *
 * 所有文本来自 @Param card 字段，由后端 done 帧一次性下发。
 *
 * 结构：
 *   Stack
 *   └── Column（clipShape PathShape + shadow + onAreaChange）
 *       ├── TicketHeader：渐变蓝抬头 + 黄高亮标题 + RouteRow（左 ?/虚线/📍 + 右文字）
 *       ├── 撕线（高 0 + dashed top border）
 *       └── 白色区：3 个 POI 项 + 2 条分隔线 + 查看更多
 */
@ComponentV2
export struct PickupConfirmCardComp {
  @Param @Require card: PickupCard

  @Local theme: ThemeState = getThemeState()
  @Local cardWidth: number = 0     // px
  @Local cardHeight: number = 0    // px
  @Local notchY: number = 0        // 缺口中心 y, px
  @Local headerH: number = 0       // 抬头高, vp

  private readonly cornerRadius: number = 16
  private readonly notchRadius: number = 9

  /** 票根轮廓 path：4 圆角 + 左右半圆缺口；首帧 / 太矮 / 越界都有兜底 */
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
        // ============ 渐变抬头 ============
        this.TicketHeader()

        // ============ 撕线 ============
        Row()
          .width('100%')
          .height(0)
          .border({
            width: { top: 1 },
            color: this.theme.ticketLine,
            style: BorderStyle.Dashed
          })

        // ============ 白色区：N 项 POI + 分隔线 + 查看更多 ============
        Column({ space: 16 }) {
          ForEach(this.card.points, (_p: PickupPoint, i: number) => {
            if (i > 0) {
              this.Divider()
            }
            if (i === 0) {
              this.LocationItemFull(0)
            } else {
              this.LocationItemSimple(i)
            }
          })
          this.MoreButton()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor(this.theme.ticketSurface)
      }
      .width('100%')
      .backgroundColor(this.theme.ticketSurface)
      .clipShape(new PathShape({ commands: this.getCardPath() }))
      .shadow({
        radius: 14,
        color: this.theme.ticketShadow,
        offsetX: 0,
        offsetY: 6
      })
      .onAreaChange((_o: Area, n: Area) => {
        this.cardWidth = vp2px(Number(n.width))
        this.cardHeight = vp2px(Number(n.height))
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: '92%' })
  }

  // ────── @Builder：渐变抬头 ──────
  @Builder
  TicketHeader() {
    Stack() {
      // 背景层：品牌蓝 + 横向白→透
      Column()
        .width('100%')
        .height(this.headerH)
        .backgroundColor(this.theme.ticketBrand)
        .linearGradient({
          angle: 90,
          colors: [[this.theme.ticketGradOpaque, 0.0], [this.theme.ticketGradClear, 1.0]]
        })

      // 内容层 + 纵向半透白→白
      Column() {
        // 标题 + 102×8 黄高亮
        Stack({ alignContent: Alignment.BottomStart }) {
          Row()
            .width(100)
            .height(8)
            .backgroundColor(this.theme.ticketYellow)
            .borderRadius(4)

          Text(this.card.title)
            .fontSize(20)
            .lineHeight(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ticketTextHeavy)
        }

        this.RouteRow()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .linearGradient({
        angle: 180,
        colors: [[this.theme.ticketGradVTop, 0.0], [this.theme.ticketGradOpaque, 1.0]]
      })
      .onAreaChange((_o: Area, n: Area) => {
        this.headerH = Number(n.height)
        this.notchY = vp2px(Number(n.height))
      })
    }
    .width('100%')
  }

  // ────── @Builder：路由行（左 12 宽 Column 装 ?/虚线/📍，右文字 Column） ──────
  @Builder
  RouteRow() {
    Row() {
      // 左列：? + 虚线 + 📍
      Column() {
        Text('?')
          .fontSize(8)
          .fontColor(this.theme.ticketOnBrand)
          .textAlign(TextAlign.Center)
          .width(12)
          .height(12)
          .lineHeight(12)
          .backgroundColor(this.theme.ticketTextHeavy)
          .borderRadius(256)
          .margin({ top: 2 })

        // Line()
        //   .width(12)
        //   .height(18)
        //   .startPoint([6, 0])
        //   .endPoint([6, 18])
        //   .stroke(this.theme.ticketDash)
        //   .strokeWidth(1)
        //   .strokeDashArray([2, 2])
        // 6段

        Line()
          .width(12)
          .height(18)
          .startPoint([6, 0])
          .endPoint([6, 18])
          .stroke(this.theme.ticketDash)
          .strokeWidth(1)
          .strokeDashArray([4, 3])
        //   三段
        Image($r('app.media.location'))
          .width(12)
          .height(12)
          .objectFit(ImageFit.Contain)
          .draggable(false)
      }
      .width(12)
      .alignItems(HorizontalAlign.Center)

      // 右列：question + currentLocation
      Column() {
        Text(this.card.question)
          .fontSize(12)
          .lineHeight(16)
          .fontColor(this.theme.ticketTextHeavy)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.card.currentLocation)
          .fontSize(12)
          .lineHeight(16)
          .fontColor(this.theme.ticketTextMuted)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .margin({top:14})
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.margin({left:4})
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({top:16})
  }

  // ────── @Builder：序号圆点 ──────
  @Builder
  IndexBadge(num: string) {
    Stack() {
      Circle({ width: 16, height: 16 }).fill(this.theme.ticketBrand)
      Text(num)
        .fontSize(10)
        .fontColor(this.theme.ticketOnBrand)
        .fontWeight(FontWeight.Bold)
    }
    .width(16)
    .height(16)
  }

  // ────── @Builder：分隔线 ──────
  @Builder
  Divider() {
    Row()
      .width('100%')
      .height(0.5)
      .backgroundColor(this.theme.ticketLine)
  }

  // ────── @Builder：第 1 项 POI（完整，带进站口 + 三横线菜单） ──────
  @Builder
  LocationItemFull(index: number) {
    Column({ space: 6 }) {
      // 序号 + 名称 + 距离
      Row() {
        this.IndexBadge(this.card.points[index].index.toString())

        Text(this.card.points[index].name)
          .margin({ left: 4 })
          .fontSize(14)
          .lineHeight(18)
          .fontColor(this.theme.ticketTextHeavy)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text(this.card.points[index].distance)
          .fontSize(10)
          .lineHeight(12)
          .fontColor(this.theme.ticketTextLite)
          .margin({ left: 4 })
      }
      .width('100%')

      // 地址
      Text(this.card.points[index].address)
        .fontSize(12)
        .lineHeight(16)
        .fontColor(this.theme.ticketTextLite)
        .width('100%')

      // 进站口 chip + 三横线菜单
      Row() {
        Text(this.card.points[index].entrance)
          .fontSize(12)
          .lineHeight(16)
          .fontColor(this.theme.ticketTextHeavy)
          .fontWeight(FontWeight.Regular)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .border({ width: 1, color: this.theme.ticketLine, radius: 8 })

        Column() {
          Image($r('app.media.list'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
            .draggable(false)
        }
        .padding(7)
        .border({ width: 1, color: this.theme.ticketLine, radius: 8 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({left:4})
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ────── @Builder：第 2 / 3 项 POI（无进站口） ──────
  @Builder
  LocationItemSimple(index: number) {
    Column({ space: 6 }) {
      // 序号 + 名称 + 距离
      Row() {
        this.IndexBadge(this.card.points[index].index.toString())

        Text(this.card.points[index].name)
          .margin({ left: 4 })
          .fontSize(14)
          .lineHeight(18)
          .fontColor(this.theme.ticketTextHeavy)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text(this.card.points[index].distance)
          .fontSize(10)
          .lineHeight(12)
          .fontColor(this.theme.ticketTextLite)
          .margin({ left: 4 })
      }
      .width('100%')

      // 地址
      Text(this.card.points[index].address)
        .fontSize(12)
        .lineHeight(16)
        .fontColor(this.theme.ticketTextLite)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ────── @Builder：查看更多 ──────
  @Builder
  MoreButton() {
    Row() {
      Text(this.card.moreText)
        .fontSize(12)
        .lineHeight(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.ticketBrand)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(this.theme.ticketBrandThin)
    .borderRadius(8)
  }
}
