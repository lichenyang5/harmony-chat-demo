import { ThemeState } from 'common'
import { Product } from '../models/productModel'

/**
 * 商品卡片组件。
 *
 * 职责：纯展示。商品图 + 名称 + 描述 + 价格（含原价划线）+ 评分 + 销量 + 角标。
 * 点击事件通过 @Event onTap 上报给父组件（首页/搜索结果页），子组件
 * 不直接耦合路由或 Controller。
 *
 * V2 父子通信约定：
 * - @Param product：父传入的商品（单向只读）
 * - @Event onTap：点击回调，避免父组件把整个 Controller 塞进来
 * - @Consumer theme：从祖先 HomePage 拿全局主题，不需要逐层透传
 */
@ComponentV2
export struct ProductCardComp {
  /** 父传入的商品对象 */
  @Param product: Product = new Product()
  /** 点击卡片回调，默认 noop */
  @Event onTap: (p: Product) => void = (_p: Product) => {}

  /** 全局主题（从祖先 HomePage 透传） */
  @Consumer() theme: ThemeState = new ThemeState()

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 6 }) {
        // 商品图（rawfile 加载本地图，product.image 形如 'images/1.png'）
        Image($rawfile(this.product.image))
          .width('100%')
          .height(90)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)

        // 商品名（单行省略）
        Text(this.product.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 简短描述（单行省略）
        Text(this.product.desc)
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 价格行：当前价 + 原价划线（仅当原价 > 现价才显示）
        Row({ space: 6 }) {
          Text(`¥${this.product.price}`)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.danger)

          if (this.product.originalPrice > this.product.price) {
            Text(`¥${this.product.originalPrice}`)
              .fontSize(11)
              .fontColor(this.theme.textTertiary)
              .decoration({ type: TextDecorationType.LineThrough })
          }
        }

        // 评分 + 销量行
        Row() {
          Text(`⭐ ${this.product.rating}`)
            .fontSize(10)
            .fontColor(this.theme.textSecondary)

          Blank()

          Text(`已售 ${this.product.sales}`)
            .fontSize(10)
            .fontColor(this.theme.textTertiary)
        }
        .width('100%')
      }
      .width('100%')
      .padding(10)
      .backgroundColor(this.theme.surface)
      .borderRadius(12)
      .shadow({
        radius: 4,
        color: this.theme.shadowColor,
        offsetY: 2
      })

      // 右上角 tag 角标（"新品"/"热门"/"推荐"等）
      if (this.product.tag) {
        Text(this.product.tag)
          .fontSize(10)
          .fontColor(this.theme.onPrimary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.theme.primary)
          .borderRadius({ topRight: 12, bottomLeft: 8 })
      }
    }
    .onClick(() => { this.onTap(this.product) })
  }
}
