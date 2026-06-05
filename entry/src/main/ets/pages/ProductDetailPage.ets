import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { HMRouterMgr } from '@hadss/hmrouter'
import { ThemeState, getThemeState } from '../viewmodel/ThemeState'
import { ProductDetailViewModel } from '../viewmodel/ProductDetailViewModel'
import { ProductDetailController } from '../controller/ProductDetailController'

/**
 * 商品详情页。
 *
 * 职责：纯 UI 渲染。所有业务逻辑（路由参数解析、生命周期观察、
 * 加购管理）均委托给 ProductDetailController。
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
    // 从路由传参中读取商品，并注册页面生命周期观察者
    this.controller.initFromParam()
    this.controller.initLifecycle()
  }

  aboutToDisappear(): void {
    // 移除生命周期观察者，防止内存泄漏
    this.controller.removeLifecycle()
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  build() {
    Column() {
      // ── 顶部导航栏 ──────────────────────────────────────────────────────
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(this.theme.textPrimary)
          .padding(12)
          .onClick(() => {
            HMRouterMgr.pop()
          })

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

      Scroll() {
        Column({ space: 12 }) {
          // ── 商品封面占位 ───────────────────────────────────────────────
          Row()
            .width('100%')
            .height(200)
            .backgroundColor(this.theme.placeholderBg)

          // ── 商品信息卡 ─────────────────────────────────────────────────
          Column({ space: 10 }) {
            Row() {
              Text(`¥${this.vm.product.price}`)
                .fontSize(26)
                .fontColor(this.theme.danger)
                .fontWeight(FontWeight.Bold)

              Blank()

              if (this.vm.product.tag) {
                Text(this.vm.product.tag)
                  .fontSize(12)
                  .fontColor(this.theme.primary)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .border({ width: 1, color: this.theme.primary })
                  .borderRadius(12)
              }
            }
            .width('100%')

            Text(this.vm.product.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)

            Text(this.vm.product.desc)
              .fontSize(14)
              .fontColor(this.theme.textSecondary)
              .lineHeight(22)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.theme.surface)
          .borderRadius(12)

          // ── 路由传参展示（学习用）──────────────────────────────────────
          Column({ space: 8 }) {
            Text('路由传参内容（getCurrentParam）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            Text(`id: ${this.vm.product.id}`)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontFamily('monospace')

            Text(`name: ${this.vm.product.name}`)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontFamily('monospace')

            Text(`price: ${this.vm.product.price}`)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontFamily('monospace')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.theme.infoBg)
          .borderRadius(10)
          .border({ width: 1, color: this.theme.infoBorder })

          // ── 生命周期日志（学习用）─────────────────────────────────────
          Column({ space: 6 }) {
            Text('⏱ 页面生命周期日志（addObserver）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            if (this.vm.lifecycleLog.length === 0) {
              Text('等待生命周期事件...')
                .fontSize(12)
                .fontColor(this.theme.textTertiary)
            } else {
              ForEach(this.vm.lifecycleLog, (log: string) => {
                Text(log)
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .fontFamily('monospace')
                  .width('100%')
              })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.theme.warningBg)
          .borderRadius(10)
          .border({ width: 1, color: this.theme.warningBorder })

          // ── 加购区域 ───────────────────────────────────────────────────
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
              .onClick(() => {
                this.controller.decreaseCart()
              })

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
              .onClick(() => {
                this.controller.addToCart()
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.theme.surface)
          .borderRadius(12)
        }
        .padding({ bottom: 100 })
      }
      .layoutWeight(1)

      // ── 底部按钮：确认加购并返回（携带数量 popParam）────────────────
      Row({ space: 12 }) {
        Button('返回')
          .layoutWeight(1)
          .height(48)
          .backgroundColor(this.theme.secondaryButtonBg)
          .fontColor(this.theme.secondaryButtonText)
          .onClick(() => {
            HMRouterMgr.pop()
          })

        Button(`加入购物车${this.vm.addCount > 0 ? `（${this.vm.addCount}）` : ''}`)
          .layoutWeight(2)
          .height(48)
          .enabled(this.vm.addCount > 0)
          .backgroundColor(this.vm.addCount > 0 ? this.theme.primary : this.theme.disabledBg)
          .fontColor(this.theme.onPrimary)
          .onClick(() => {
            this.controller.confirmAndBack()
          })
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
