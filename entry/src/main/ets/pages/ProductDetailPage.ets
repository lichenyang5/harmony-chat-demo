import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { HMRouterMgr } from '@hadss/hmrouter'
import { HMLifecycleState } from '@hadss/hmrouter'
import { Product } from '../models/productModel'
import { ThemeState, getThemeState } from '../viewmodel/ThemeState'

@HMRouter({ pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL })
@ComponentV2
export struct ProductDetailPage {
  @Local product: Product = new Product()
  @Local addCount: number = 0
  @Local lifecycleLog: string[] = []
  @Local theme: ThemeState = getThemeState()

  // ─── 生命周期 ─────────────────────────────────────────────
  aboutToAppear(): void {
    // 1. 读取路由传参（push 时 param 字段传入的对象）
    const param = HMRouterMgr.getCurrentParam()
    if (param) {
      this.product = param as Product
    }

    // 2. 注册页面生命周期观察者
    // getCurrentLifecycleOwner() 返回当前页面的生命周期持有者
    const owner = HMRouterMgr.getCurrentLifecycleOwner()
    if (!owner) {
      return
    }

    owner.addObserver(HMLifecycleState.onShown, () => {
      this.appendLog('onShown ▶ 页面显示/从子页返回')
    })

    owner.addObserver(HMLifecycleState.onHidden, () => {
      this.appendLog('onHidden ⏸ 页面隐藏（跳转子页时）')
    })

    owner.addObserver(HMLifecycleState.onDisAppear, () => {
      this.appendLog('onDisAppear ✕ 页面销毁')
    })
  }

  aboutToDisappear(): void {
    // 防止内存泄漏：组件销毁时移除所有观察者
    const owner = HMRouterMgr.getCurrentLifecycleOwner()
    owner?.removeObserver(HMLifecycleState.onShown)
    owner?.removeObserver(HMLifecycleState.onHidden)
    owner?.removeObserver(HMLifecycleState.onDisAppear)
  }

  private appendLog(msg: string): void {
    const time = new Date().toLocaleTimeString()

    // 最多保留 5 条，超出时移除最旧的
    if (this.lifecycleLog.length >= 5) {
      this.lifecycleLog.shift()
    }

    this.lifecycleLog.push(`[${time}] ${msg}`)
  }

  // ─── 加购并返回 ────────────────────────────────────────────
  private addToCart(): void {
    this.addCount++

    // setPopParam：设置 pop 时返回给调用方 onResult 的数据
    HMRouterMgr.setPopParam(this.addCount)
  }

  private confirmAndBack(): void {
    // pop 后，HomeTabComp 的 onResult 会收到 addCount
    HMRouterMgr.pop()
  }

  // ─── UI ───────────────────────────────────────────────────
  build() {
    Column() {
      // 顶部导航栏
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
          // 商品封面
          Row()
            .width('100%')
            .height(200)
            .backgroundColor(this.theme.placeholderBg)

          // 商品信息卡
          Column({ space: 10 }) {
            Row() {
              Text(`¥${this.product.price}`)
                .fontSize(26)
                .fontColor(this.theme.danger)
                .fontWeight(FontWeight.Bold)

              Blank()

              if (this.product.tag) {
                Text(this.product.tag)
                  .fontSize(12)
                  .fontColor(this.theme.primary)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .border({ width: 1, color: this.theme.primary })
                  .borderRadius(12)
              }
            }
            .width('100%')

            Text(this.product.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)

            Text(this.product.desc)
              .fontSize(14)
              .fontColor(this.theme.textSecondary)
              .lineHeight(22)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.theme.surface)
          .borderRadius(12)

          // ── 路由传参展示（学习用）──────────────────────
          Column({ space: 8 }) {
            Text('路由传参内容（getCurrentParam）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            Text(`id: ${this.product.id}`)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontFamily('monospace')

            Text(`name: ${this.product.name}`)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontFamily('monospace')

            Text(`price: ${this.product.price}`)
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontFamily('monospace')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.theme.infoBg)
          .borderRadius(10)
          .border({ width: 1, color: this.theme.infoBorder })

          // ── 生命周期日志（学习用）─────────────────────
          Column({ space: 6 }) {
            Text('⏱ 页面生命周期日志（addObserver）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            if (this.lifecycleLog.length === 0) {
              Text('等待生命周期事件...')
                .fontSize(12)
                .fontColor(this.theme.textTertiary)
            } else {
              ForEach(this.lifecycleLog, (log: string) => {
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

          // 加购区域
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
                if (this.addCount > 0) {
                  this.addCount--
                  HMRouterMgr.setPopParam(this.addCount)
                }
              })

            Text(`${this.addCount}`)
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
                this.addToCart()
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

      // 底部按钮：确认加购并返回（携带数量 popParam）
      Row({ space: 12 }) {
        Button('返回')
          .layoutWeight(1)
          .height(48)
          .backgroundColor(this.theme.secondaryButtonBg)
          .fontColor(this.theme.secondaryButtonText)
          .onClick(() => {
            HMRouterMgr.pop()
          })

        Button(`加入购物车${this.addCount > 0 ? `（${this.addCount}）` : ''}`)
          .layoutWeight(2)
          .height(48)
          .enabled(this.addCount > 0)
          .backgroundColor(this.addCount > 0 ? this.theme.primary : this.theme.disabledBg)
          .fontColor(this.theme.onPrimary)
          .onClick(() => {
            this.confirmAndBack()
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