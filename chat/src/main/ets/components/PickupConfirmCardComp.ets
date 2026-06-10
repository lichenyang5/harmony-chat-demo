import { PickupCard } from '../models/chatModel'
import { PathShape } from '@kit.ArkUI'

/**
 * 确认上车点卡片（票根风格 — 纯 UI 复刻版）
 *
 * 当前阶段所有文本写死，不读 card 字段，避免后端字段缺失导致渲染崩溃。
 * card 参数保留只是为了兼容外部调用方（ChatListComp 在传 card）。
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
            color: '#1A000000',
            style: BorderStyle.Dashed
          })

        // ============ 白色区：3 项 POI + 分隔线 + 查看更多 ============
        Column({ space: 16 }) {
          this.LocationItemFull()
          this.Divider()
          this.LocationItemSimple('2', '高铁西九龙站(K出口)')
          this.Divider()
          this.LocationItemSimple('3', '高铁西九龙站(K出口)')
          this.MoreButton()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor(Color.White)
      }
      .width('100%')
      .backgroundColor(Color.White)
      .clipShape(new PathShape({ commands: this.getCardPath() }))
      .shadow({
        radius: 14,
        color: '#22000000',
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
        .backgroundColor('#FF00B5D9')
        .linearGradient({
          angle: 90,
          colors: [['#FFFFFFFF', 0.0], ['#00FFFFFF', 1.0]]
        })

      // 内容层 + 纵向半透白→白
      Column() {
        // 标题 + 102×8 黄高亮
        Stack({ alignContent: Alignment.BottomStart }) {
          Row()
            .width(100)
            .height(8)
            .backgroundColor('#FFD91A')
            .borderRadius(4)

          Text('确认上车点')
            .fontSize(20)
            .lineHeight(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E6000000')
        }

        this.RouteRow()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .linearGradient({
        angle: 180,
        colors: [['#B3FFFFFF', 0.0], ['#FFFFFFFF', 1.0]]
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
        // 问号：直接用 Text 当带背景圆，textAlign+lineHeight 让 "?" 严格几何居中
        Text('?')
          .fontSize(8)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width(12)
          .height(12)
          .lineHeight(12)
          .backgroundColor('#E6000000')
          .borderRadius(256)
          .margin({ top: 2 })

        Line()
          .width(1)
          .height(12)
          .startPoint([0, 0])
          .endPoint([0, 12])
          .stroke('#B5BAC4')
          .strokeWidth(1)
          .strokeDashArray([2, 2])

        Image($r('app.media.location'))
          .width(12)
          .height(12)
          .objectFit(ImageFit.Contain)
          .draggable(false)
          // 跟虚线之间留 2vp gap，避免虚线贴到图标上沿（这个图标占满 12×12，没有内边距）
          .margin({ top: 2 })
      }
      .width(12)
      .alignItems(HorizontalAlign.Center)

      // 右列：question + currentLocation（写死）
      Column() {
        Text('您在哪里上车?')
          .fontSize(12)
          .lineHeight(16)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('香港中国企业协会')
          .fontSize(12)
          .lineHeight(16)
          .fontColor('#66000000')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .margin({top:10})
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.margin({left:4})
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({top:22})
  }

  // ────── @Builder：序号圆点 ──────
  @Builder
  IndexBadge(num: string) {
    Stack() {
      Circle({ width: 16, height: 16 }).fill('#FF00B5D9')
      Text(num)
        .fontSize(10)
        .fontColor('#FFFFFF')
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
      .backgroundColor('#1A000000')
  }

  // ────── @Builder：第 1 项 POI（完整，带进站口 + 三横线菜单） ──────
  @Builder
  LocationItemFull() {
    Column({ space: 6 }) {
      // 序号 + 名称 + 距离
      Row() {
        this.IndexBadge('1')

        Text('香港西九龙站')
          .margin({ left: 4 })
          .fontSize(14)
          .lineHeight(18)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text('65.9km')
          .fontSize(10)
          .lineHeight(12)
          .fontColor('#99000000')
          .margin({ left: 4 })
      }
      .width('100%')

      // 地址
      Text('香港特别行政区油尖旺区柯士甸道西3号')
        .fontSize(12)
        .lineHeight(16)
        .fontColor('#99000000')
        .width('100%')

      // 进站口 chip + 三横线菜单
      Row() {
        Text('进站口1')
          .fontSize(12)
          .lineHeight(16)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Regular)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .border({ width: 1, color: '#1A000000', radius: 8 })

        Column() {
          Image($r('app.media.list'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
            .draggable(false)
        }
        .padding(7)
        .border({ width: 1, color: '#1A000000', radius: 8 })
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
  LocationItemSimple(num: string, name: string) {
    Column({ space: 6 }) {
      // 序号 + 名称 + 距离
      Row() {
        this.IndexBadge(num)

        Text(name)
          .margin({ left: 4 })
          .fontSize(14)
          .lineHeight(18)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text('65.9km')
          .fontSize(10)
          .lineHeight(12)
          .fontColor('#99000000')
          .margin({ left: 4 })
      }
      .width('100%')

      // 地址
      Text('香港特别行政区油尖旺区柯士甸道西3号')
        .fontSize(12)
        .lineHeight(16)
        .fontColor('#99000000')
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ────── @Builder：查看更多 ──────
  @Builder
  MoreButton() {
    Row() {
      Text('查看更多')
        .fontSize(12)
        .lineHeight(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FF00B5D9')
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .backgroundColor('#1A00B5D9')
    .borderRadius(8)
  }
}
