import { ThemeState } from 'common'
import { Product } from '../models/productModel'
import { FavoriteState, getFavoriteState } from '../viewmodel/FavoriteState'

/**
 * AI 内容卡片组件。
 *
 * 职责：纯展示。封面 + 标题 + 摘要 + 内容类型 + 评分 + 使用次数 + 角标 + 收藏。
 * 点击事件通过 @Event onTap 上报给父组件（首页/搜索结果页），子组件
 * 不直接耦合路由或 Controller。
 *
 * V2 父子通信约定：
 * - @Param product：父传入的商品（单向只读）
 * - @Event onTap：点击回调，避免父组件把整个 Controller 塞进来
 * - @Consumer theme：从祖先 HomePage 拿全局主题，不需要逐层透传
 *
 * 收藏：直接拿全局 FavoriteState 单例（PersistenceV2 持久化），
 * 点击心形按钮 toggle，UI 响应式刷新。心形按钮自带 onClick，
 * ArkUI 默认不冒泡，外层 Stack 的 onClick 不会被触发。
 */
@ComponentV2
export struct ProductCardComp {
  /** 父传入的商品对象 */
  @Param product: Product = new Product()
  /** 点击卡片回调，默认 noop */
  @Event onTap: (p: Product) => void = (_p: Product) => {}

  /** 全局主题（从祖先 HomePage 透传） */
  @Consumer() theme: ThemeState = new ThemeState()
  /** 全局收藏单例（持久化） */
  @Local favorite: FavoriteState = getFavoriteState()

  build() {
    // Stack alignContent 设 TopEnd：tag 自然落在右上角；
    // 心形按钮用 .position() 绝对定位到左上角，避免 .align() 在
    // 部分 ArkUI 版本里对 Stack 子节点不生效导致全部子元素跑到中间。
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 6 }) {
        // 同一张 Demo 图按服务端高度裁切，形成错落的瀑布流节奏。
        Image($rawfile(this.product.image))
          .width('100%')
          .height(this.product.coverHeight)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)

        // 标题最多两行；行数也会被分列算法纳入高度预估。
        Text(this.product.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 摘要允许三行，长短文案进一步拉开内容卡片高度。
        Text(this.product.desc)
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 内容类型 + 免费使用状态。
        Row() {
          Text(this.product.contentType === 'assistant' ? 'AI 助手' : '提示词')
            .fontSize(10)
            .fontColor(this.theme.primary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.theme.placeholderBg)
            .borderRadius(6)

          Blank()

          Text('免费使用')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.primary)
        }
        .width('100%')

        // 评分 + 销量行
        Row() {
          Text(`⭐ ${this.product.rating}`)
            .fontSize(10)
            .fontColor(this.theme.textSecondary)

          Blank()

          Text(`${this.product.sales} 人使用`)
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

      // 左上角心形收藏按钮：position 绝对定位（相对父 Stack 左上角偏移）。
      // 半透明黑底圈保证白底图片上心形也清晰可见。
      Text(this.favorite.has(this.product.id) ? '♥' : '♡')
        .fontSize(16)
        .fontColor(this.favorite.has(this.product.id) ? this.theme.danger : Color.White)
        .textAlign(TextAlign.Center)
        .width(26)
        .height(26)
        .borderRadius(13)
        .backgroundColor('#66000000')
        .position({ x: 8, y: 8 })
        .onClick(() => this.favorite.toggle(this.product.id))

      // 右上角 tag 角标（"新品"/"热门"/"推荐"等），跟随 Stack 默认 TopEnd 对齐
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
