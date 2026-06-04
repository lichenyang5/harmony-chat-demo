import { EntryRoutes } from '../constants/EntryRoutes'
import { HMRouter } from '@hadss/hmrouter'
import { HMRouterMgr } from '@hadss/hmrouter'
import { HMLifecycleState } from '@hadss/hmrouter'
import { Product } from '../models/productModel'

@HMRouter({ pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL })
@ComponentV2
export struct ProductDetailPage {
  @Local product: Product = new Product()
  @Local addCount: number = 0           // 本次加购数量
  @Local lifecycleLog: string[] = []    // 生命周期日志（用于学习观察）

  // ─── 生命周期 ─────────────────────────────────────────────
  aboutToAppear(): void {
    // 1. 读取路由传参（push 时 param 字段传入的对象）
    const param = HMRouterMgr.getCurrentParam()
    if (param) {
      this.product = param as Product
    }

    // 2. 注册页面生命周期观察者
    //    getCurrentLifecycleOwner() 返回当前页面的生命周期持有者
    const owner = HMRouterMgr.getCurrentLifecycleOwner()
    if (!owner) return

    owner.addObserver(HMLifecycleState.onShown, () => {
      this.appendLog('onShown  ▶ 页面显示/从子页返回')
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
          .padding(12)
          .onClick(() => { HMRouterMgr.pop() })
        Text('商品详情').fontSize(17).fontWeight(FontWeight.Medium)
        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#EBEBEB' })

      Scroll() {
        Column({ space: 12 }) {

          // 商品封面
          Row()
            .width('100%')
            .height(200)
            .backgroundColor('#E8EEFF')

          // 商品信息卡
          Column({ space: 10 }) {
            Row() {
              Text(`¥${this.product.price}`)
                .fontSize(26)
                .fontColor('#FF4D4F')
                .fontWeight(FontWeight.Bold)
              Blank()
              if (this.product.tag) {
                Text(this.product.tag)
                  .fontSize(12)
                  .fontColor('#007DFF')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .border({ width: 1, color: '#007DFF' })
                  .borderRadius(12)
              }
            }
            .width('100%')

            Text(this.product.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)

            Text(this.product.desc)
              .fontSize(14)
              .fontColor('#666666')
              .lineHeight(22)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)

          // ── 路由传参展示（学习用）──────────────────────
          Column({ space: 8 }) {
            Text('📦 路由传参内容（getCurrentParam）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#444444')
            Text(`id: ${this.product.id}`)
              .fontSize(12).fontColor('#666666').fontFamily('monospace')
            Text(`name: ${this.product.name}`)
              .fontSize(12).fontColor('#666666').fontFamily('monospace')
            Text(`price: ${this.product.price}`)
              .fontSize(12).fontColor('#666666').fontFamily('monospace')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#F8F9FF')
          .borderRadius(10)
          .border({ width: 1, color: '#DDEAFF' })

          // ── 生命周期日志（学习用）─────────────────────
          Column({ space: 6 }) {
            Text('⏱ 页面生命周期日志（addObserver）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#444444')
            if (this.lifecycleLog.length === 0) {
              Text('等待生命周期事件...')
                .fontSize(12)
                .fontColor('#AAAAAA')
            } else {
              ForEach(this.lifecycleLog, (log: string) => {
                Text(log)
                  .fontSize(11)
                  .fontColor('#555555')
                  .fontFamily('monospace')
                  .width('100%')
              })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFBF0')
          .borderRadius(10)
          .border({ width: 1, color: '#FFE8A0' })

          // 加购区域
          Row({ space: 16 }) {
            Text('加购数量').fontSize(14)
            Blank()
            Button('-')
              .width(36).height(36)
              .fontSize(18)
              .backgroundColor('#F0F0F0')
              .fontColor('#333333')
              .onClick(() => { if (this.addCount > 0) { this.addCount-- } })

            Text(`${this.addCount}`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width(40)
              .textAlign(TextAlign.Center)

            Button('+')
              .width(36).height(36)
              .fontSize(18)
              .backgroundColor('#007DFF')
              .onClick(() => { this.addToCart() })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor(Color.White)
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
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => { HMRouterMgr.pop() })

        Button(`加入购物车${this.addCount > 0 ? `（${this.addCount}）` : ''}`)
          .layoutWeight(2)
          .height(48)
          .enabled(this.addCount > 0)
          .backgroundColor(this.addCount > 0 ? '#007DFF' : '#CCCCCC')
          .onClick(() => { this.confirmAndBack() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24, top: 12 })
      .backgroundColor(Color.White)
      .border({ width: { top: 0.5 }, color: '#EBEBEB' })

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }
}
