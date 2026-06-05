import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { EntryRoutes } from '../constants/EntryRoutes'
import { getThemeState, ThemeState } from '../viewmodel/ThemeState'
import { ProductDetailViewModel } from '../viewmodel/ProductDetailViewModel'
import { ProductDetailController } from '../controller/ProductDetailController'

/**
 * 商品详情页。
 *
 * 职责：纯 UI 渲染。所有业务逻辑（路由参数解析、生命周期观察、
 * 加购管理）均委托给 ProductDetailController。
 *
 * 布局：
 * - 顶部 NavBar（固定）
 * - 中间 Scroll：封面图 + RelativeContainer 商品信息卡 + 加购数量调节
 * - 底部按钮栏（固定）：返回 + 加入购物车
 *
 * 学习点：商品信息卡用 RelativeContainer 演示"规则布局"——
 * 6 个子元素通过 alignRules 互相锚定，每个元素必须设 .id()，
 * 容器自身保留 id 是 '__container__'。
 *
 * Step 3 待完善：加购按钮当前走的是 HMRouter.setPopParam → 首页 onResult 累加
 * 的老逻辑；接入全局 CartState 后改为直接 getCartState().add(product, count)。
 */
@HMRouter({ pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL })
@ComponentV2
export struct ProductDetailPage {
  /** 页面视图状态（商品、加购数量、生命周期日志），由 controller 读写 */
  @Local vm: ProductDetailViewModel = new ProductDetailViewModel()
  /** 全局主题（亮色/暗黑），用于动态颜色 */
  @Local theme: ThemeState = getThemeState()

  private controller: ProductDetailController = new ProductDetailController(this.vm)

  // ─── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    // 从路由传参（HMRouter push 时 param: product）读取商品并写入 vm
    this.controller.initFromParam()
    // 注册三个生命周期观察者（演示用，日志输出到 console）
    this.controller.initLifecycle()
  }

  aboutToDisappear(): void {
    // 移除生命周期观察者，防止内存泄漏
    this.controller.removeLifecycle()
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Column() {
      // ── 顶部 NavBar ──────────────────────────────────────────────────
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(this.theme.textPrimary)
          .padding(12)
          .onClick(() => HMRouterMgr.pop())

        Text('商品详情')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.theme.surface)
      .border({ width: { bottom: 0.5 }, color: this.theme.divider })

      // ── 中间滚动内容 ────────────────────────────────────────────────
      Scroll() {
        Column({ space: 12 }) {
          // ① 封面图（rawfile 加载本地图）
          Image($rawfile(this.vm.product.image))
            .width('100%')
            .height(240)
            .objectFit(ImageFit.Cover)

          // ② 商品信息卡 —— RelativeContainer 规则布局
          //   六个子元素：price / origPrice / tag / name / meta / desc
          //   每个元素都用 .id() 标识，alignRules 描述相对锚点
          RelativeContainer() {
            // ── 当前价（左上角）──
            Text(`¥${this.vm.product.price}`)
              .id('price')
              .fontSize(26)
              .fontColor(this.theme.danger)
              .fontWeight(FontWeight.Bold)
              .alignRules({
                top: { anchor: '__container__', align: VerticalAlign.Top },
                start: { anchor: '__container__', align: HorizontalAlign.Start }
              })

            // ── 原价划线（紧贴 price 右侧，仅当原价大于现价显示）──
            if (this.vm.product.originalPrice > this.vm.product.price) {
              Text(`¥${this.vm.product.originalPrice}`)
                .id('origPrice')
                .fontSize(13)
                .fontColor(this.theme.textTertiary)
                .decoration({ type: TextDecorationType.LineThrough })
                .alignRules({
                  bottom: { anchor: 'price', align: VerticalAlign.Bottom },
                  start: { anchor: 'price', align: HorizontalAlign.End }
                })
                .margin({ left: 8 })
            }

            // ── tag 角标（右上角）──
            if (this.vm.product.tag) {
              Text(this.vm.product.tag)
                .id('tag')
                .fontSize(12)
                .fontColor(this.theme.primary)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .border({ width: 1, color: this.theme.primary })
                .borderRadius(12)
                .alignRules({
                  top: { anchor: '__container__', align: VerticalAlign.Top },
                  end: { anchor: '__container__', align: HorizontalAlign.End }
                })
            }

            // ── 商品名（price 下方）──
            Text(this.vm.product.name)
              .id('name')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
              .alignRules({
                top: { anchor: 'price', align: VerticalAlign.Bottom },
                start: { anchor: '__container__', align: HorizontalAlign.Start }
              })
              .margin({ top: 12 })

            // ── 元信息（name 下方）⭐ 评分 + 销量 + 库存 ──
            Text(`⭐ ${this.vm.product.rating}    已售 ${this.vm.product.sales}    库存 ${this.vm.product.stock}`)
              .id('meta')
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .alignRules({
                top: { anchor: 'name', align: VerticalAlign.Bottom },
                start: { anchor: '__container__', align: HorizontalAlign.Start }
              })
              .margin({ top: 8 })

            // ── 商品描述（meta 下方，撑满左右）──
            Text(this.vm.product.desc)
              .id('desc')
              .fontSize(14)
              .fontColor(this.theme.textSecondary)
              .lineHeight(22)
              .alignRules({
                top: { anchor: 'meta', align: VerticalAlign.Bottom },
                start: { anchor: '__container__', align: HorizontalAlign.Start },
                end: { anchor: '__container__', align: HorizontalAlign.End }
              })
              .margin({ top: 10 })
          }
          .width('100%')
          .height(180)              // ★ RelativeContainer 必须给固定高度，不能 'auto'
          .padding(16)
          .backgroundColor(this.theme.surface)
          .borderRadius(12)

          // ③ 加购数量调节区
          Row({ space: 16 }) {
            Text('加购数量')
              .fontSize(14)
              .fontColor(this.theme.textPrimary)

            Blank()

            Button('-')
              .width(36)
              .height(36)
              .fontSize(18)
              .backgroundColor(this.theme.secondaryButtonBg)
              .fontColor(this.theme.secondaryButtonText)
              .onClick(() => this.controller.decreaseCart())

            Text(`${this.vm.addCount}`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
              .width(40)
              .textAlign(TextAlign.Center)

            Button('+')
              .width(36)
              .height(36)
              .fontSize(18)
              .backgroundColor(this.theme.primary)
              .fontColor(this.theme.onPrimary)
              .onClick(() => this.controller.addToCart())
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.theme.surface)
          .borderRadius(12)
        }
        .padding({ left: 12, right: 12, bottom: 100 })
      }
      .layoutWeight(1)

      // ── 底部按钮栏：返回 + 加入购物车 ────────────────────────────────
      Row({ space: 12 }) {
        Button('返回')
          .layoutWeight(1)
          .height(48)
          .backgroundColor(this.theme.secondaryButtonBg)
          .fontColor(this.theme.secondaryButtonText)
          .onClick(() => HMRouterMgr.pop())

        Button(`加入购物车${this.vm.addCount > 0 ? `（${this.vm.addCount}）` : ''}`)
          .layoutWeight(2)
          .height(48)
          // 库存为 0 或还没选数量时禁用
          .enabled(this.vm.addCount > 0 && this.vm.product.stock > 0)
          .backgroundColor(this.vm.addCount > 0 ? this.theme.primary : this.theme.disabledBg)
          .fontColor(this.theme.onPrimary)
          .onClick(() => this.controller.confirmAndBack())
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24, top: 12 })
      .backgroundColor(this.theme.surface)
      .border({ width: { top: 0.5 }, color: this.theme.divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bg)
  }
}
