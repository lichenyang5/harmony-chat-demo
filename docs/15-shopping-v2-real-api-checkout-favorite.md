# 鸿蒙电商 Demo v2：真实商品接口 + 支付/订单闭环 + 收藏功能，外加一个 ArkUI V2 @Builder 响应式断链的硬核坑

> 项目：`MyApplication`
> 模块：`entry`（HAP）、`common`（HAR）、`server`（Next.js mock）
> 上一篇：[14-harmony-shopping.md](./14-harmony-shopping.md)（首页 → 详情 → 购物车全闭环）
> 本篇主题：在上一篇基础上，把"假数据 + Toast 占位的支付按钮 + 没有收藏"这些半成品全部补齐 ——
> **GET /api/products 接真实接口** / **CheckoutPage + OrderListPage 走完支付闭环** /
> **FavoriteState 再练一遍 PersistenceV2 套路**，最后踩穿了一个非常隐蔽的 **ArkUI V2
> @Builder 边界吃响应式的坑**，复盘出可以记进肌肉记忆的两条铁律。

---

## 一、这次提交到底做了什么

一张总图先：

```text
┌────────────────────────────────────────────────────────────────────┐
│  v1（上一篇）                v2（本次提交）                          │
├────────────────────────────────────────────────────────────────────┤
│  MOCK_PRODUCTS 硬编码     →  GET /api/products 真接口 + ProductBiz  │
│  ─────────────────────────────────────────────────────────────────  │
│  goPay 弹 Toast 占位      →  CheckoutPage：生成订单 → 模拟支付      │
│                              → markPaid → 清空购物车 → 跳订单列表    │
│  ─────────────────────────────────────────────────────────────────  │
│  无订单概念               →  OrderState（PersistenceV2 + @Type(Order)│
│                              嵌套对象数组）+ OrderListPage           │
│                              已支付/待支付/已取消三态徽章            │
│  ─────────────────────────────────────────────────────────────────  │
│  无收藏                   →  FavoriteState（PersistenceV2 第三份范本) │
│                              首页卡片左上心形 + 详情页右上心形       │
│                              FavoriteListPage 我的收藏              │
│  ─────────────────────────────────────────────────────────────────  │
│  我的 Tab 三个普通菜单    →  + "我的订单 N" + "我的收藏 N"          │
│                              带数字红点角标，跨页变化实时同步        │
└────────────────────────────────────────────────────────────────────┘
```

涉及的新增 / 改造文件清单：

| 层次 | 文件 | 新增/改 | 用途 |
|---|---|---|---|
| **服务端** | `server/app/api/products/route.ts` | 新增 | mock 商品列表接口 |
| **common** | `ApiConstants.ets`、`HttpUtil.ets` | 改 | 加 `PRODUCTS` 常量、`get<T>()` 方法 |
| **model** | `productModel.ets` | 改 | 移除 MOCK_PRODUCTS（接口接管） |
| **model** | `orderModel.ets` | 新增 | `Order` / `OrderItem` 两个类 |
| **imp** | `ProductImp.ets` | 新增 | HTTP 调用层 |
| **biz** | `ProductBiz.ets`、`OrderBiz.ets` | 新增 | 业务收口（解包 + 失败兜底） |
| **viewmodel** | `HomeViewModel.ets` | 改 | 加 `products / loading / error` |
| **viewmodel** | `FavoriteState.ets` | 新增 | 收藏单例（PersistenceV2） |
| **viewmodel** | `OrderState.ets` | 新增 | 订单单例（PersistenceV2 + @Type(Order)） |
| **viewmodel** | `CheckoutViewModel.ets`、`FavoriteListViewModel.ets` | 新增 | 两个新页面状态 |
| **controller** | `HomeController.ets`、`CartController.ets`、`ProfileController.ets` | 改 | 接真接口 / goPay 跳 Checkout / 新增两个跳转 |
| **controller** | `CheckoutController.ets`、`OrderListController.ets`、`FavoriteListController.ets` | 新增 | 三个新页面控制器 |
| **page** | `CheckoutPage.ets`、`OrderListPage.ets`、`FavoriteListPage.ets` | 新增 | 三个新页面 |
| **page** | `ProductDetailPage.ets` | 改 | 顶部加心形按钮 |
| **components** | `HomeTabComp.ets` | 改 | loading / error / 网格三态分支 + aboutToAppear 拉接口 |
| **components** | `ProductCardComp.ets` | 改 | 左上心形 + 修复 `.align()` 失效问题 |
| **components** | `ProfileTabComp.ets` | 改 | 加"我的订单 / 我的收藏"菜单 + 角标（**踩过 3 次才修对**） |
| **constants** | `EntryRoutes.ets` | 改 | 加 3 个页面常量 |

---

## 二、第一刀：接入真实商品接口（GET /api/products）

### 2.1 为什么做这件事

写死的 `MOCK_PRODUCTS` 看着方便，但它把"数据从哪里来"这个问题藏起来了，导致后面所有"loading 怎么处理 / error 怎么提示 / 接口失败兜底"都没法演示。这次把它彻底拔掉，让首页第一帧就走真实接口。

### 2.2 后端：Next.js 一个文件搞定

`server/app/api/products/route.ts`：

```typescript
import { NextResponse } from 'next/server'

interface Product {
  id: string
  name: string
  price: number
  originalPrice: number
  desc: string
  image: string
  tag: string
  rating: number
  sales: number
  stock: number
}

const MOCK_PRODUCTS: Product[] = [
  { id: '001', name: 'ArkTS 快速入门', price: 99, originalPrice: 129, /* ... */ },
  // ... 12 条
]

export async function GET() {
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: MOCK_PRODUCTS
  })
}
```

跟 `login/route.ts` 同一个套路：路由文件直接 `export async function GET()` / `POST()`，Next.js App Router 自动识别。返回结构延用项目的 `ApiResponse<T>` 协议（`code / message / data`）。

> 📖 Next.js Route Handlers：https://nextjs.org/docs/app/building-your-application/routing/route-handlers

### 2.3 common 层：HttpUtil 加 get

`common/.../HttpUtil.ets` 之前只有 `post<T>`，照葫芦画瓢加一个 `get<T>`：

```typescript
static get<T>(path: string): Promise<ApiResponse<T>> {
  const req = http.createHttp()
  return req.request(
    ApiConstants.BASE_URL + path,
    {
      method: http.RequestMethod.GET,
      header: { 'Content-Type': 'application/json' },
      connectTimeout: 10000,
      readTimeout: 10000
    }
  ).then(res => {
    return JSON.parse(res.result as string) as ApiResponse<T>
  }).finally(() => {
    req.destroy()
  })
}
```

`@kit.NetworkKit` 的 `http.createHttp()` + `http.RequestMethod.GET`，几乎是模板代码。`finally` 里调 `req.destroy()` 释放连接 —— 这一步千万别漏，否则连接数堆积。

> 📖 @kit.NetworkKit http 模块：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http

### 2.4 客户端三层：imp → biz → controller

这套分层鸿蒙工程里非常常见，参考已有的 `AuthImp` / `AuthBiz`：

```typescript
// imp/ProductImp.ets —— 远程数据源
export class ProductImp {
  list(): Promise<ApiResponse<Product[]>> {
    return HttpUtil.get<Product[]>(ApiConstants.PRODUCTS)
  }
}

// biz/ProductBiz.ets —— 解协议 + 兜底
export class ProductBiz {
  private imp: ProductImp = new ProductImp()

  list(): Promise<Product[]> {
    return this.imp.list().then((res) => {
      if (res.code === 200 && res.data) {
        return res.data
      }
      return [] as Product[]
    })
  }
}
```

为什么要 biz 这一层？三个理由：
1. imp 拿原始 `ApiResponse<T>`，上层不该关心 `code === 200` 这种协议细节
2. 失败时兜底返回空数组，UI 不用做空指针守卫
3. 以后接其他数据源（缓存 / 数据库 / 不同后端）只换 imp，biz 不动

### 2.5 ViewModel + Controller 加 loading / error 字段

`HomeViewModel` 从 1 个字段扩到 4 个：

```typescript
@ObservedV2
export class HomeViewModel {
  @Trace searchKeyword: string = ''
  @Trace products: Product[] = []
  @Trace loading: boolean = false
  @Trace error: string = ''
}
```

`HomeController.loadProducts()` 控制三态切换：

```typescript
async loadProducts(): Promise<void> {
  this.vm.loading = true
  this.vm.error = ''
  try {
    const list = await this.biz.list()
    this.vm.products = list
    if (list.length === 0) {
      this.vm.error = '暂无商品'
    }
  } catch (e) {
    this.vm.error = '加载失败，请下拉重试'
  } finally {
    this.vm.loading = false
  }
}
```

### 2.6 UI 三态分支：loading / error / 网格

`HomeTabComp` 的 `aboutToAppear` 拉接口，build 里按状态切换：

```typescript
aboutToAppear(): void {
  this.controller.loadProducts()
}

build() {
  Column() {
    /* ... 顶部 + 搜索框 ... */

    if (this.vm.loading && this.vm.products.length === 0) {
      Column() {
        LoadingProgress().width(40).color(this.theme.primary)
        Text('正在加载商品…')
      }
    } else if (this.vm.error.length > 0 && this.vm.products.length === 0) {
      Column() {
        Text('😢').fontSize(48)
        Text(this.vm.error)
        Button('重新加载').onClick(() => this.controller.loadProducts())
      }
    } else {
      Grid() { /* ... ForEach 商品网格 ... */ }
    }
  }
}
```

注意条件里写 `&& this.vm.products.length === 0` —— 这是个小细节：**已经有缓存数据时即使刷新失败也优先展示老数据**，不要直接把网格换成 error 文案，否则用户体验非常差。

> 📖 ArkTS 异步与状态：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-asynchronous-programming

---

## 三、FavoriteState：第二份 PersistenceV2 范本

[CartState](../entry/src/main/ets/viewmodel/CartState.ets) 已经把"持有 Product 对象数组 + @Type 还原原型"演示过一遍。这次的 `FavoriteState` 是更简单的形态 —— **只存 id 字符串数组**。

### 3.1 为什么只存 id

如果存 `Product[]`，会有两个问题：

1. **商品上下架后历史收藏失效**：服务端改价 / 删商品，本地收藏的 Product 就和真相脱节
2. **存储冗余**：12 个商品 × 10 个字段 × N 人 = 没必要的体积

所以行业惯例：**收藏只存指针（id），渲染时按 id 反查**。这次 FavoriteListPage 进来时拉一次商品接口再 filter。

```typescript
@ObservedV2
export class FavoriteState {
  @Trace favoriteIds: string[] = []

  get totalCount(): number {
    return this.favoriteIds.length
  }

  has(id: string): boolean {
    return this.favoriteIds.indexOf(id) >= 0
  }

  toggle(id: string): void {
    if (this.has(id)) {
      this.favoriteIds = this.favoriteIds.filter((x) => x !== id)
    } else {
      const next = this.favoriteIds.slice()
      next.push(id)
      this.favoriteIds = next
    }
  }
}

export function getFavoriteState(): FavoriteState {
  return PersistenceV2.connect(FavoriteState, 'FavoriteState', () => new FavoriteState())!
}
```

### 3.2 数组操作铁律：整体替换才触发响应

注意 toggle 里没有用 `this.favoriteIds.push(id)`，而是：

```typescript
const next = this.favoriteIds.slice()  // 浅拷贝
next.push(id)
this.favoriteIds = next                // 整体替换
```

为什么？这是 V2 装饰器对数组 / 对象的官方写法约束 —— **`@Trace` 标注的字段需要被整体赋值，原地 mutation（push / splice / 直接改字段）不一定触发响应**。

> 实际上 CartState 里 `add()` 用了原地 `push` 也能 work，说明这条规则在不同 ArkUI 版本表现有差异。为了稳，**整体替换永远不会错**。

> 📖 @ObservedV2 / @Trace：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-observedv2-and-trace

### 3.3 UI 两处接入

**ProductCardComp**（首页商品卡左上角心形）：

```typescript
@Local favorite: FavoriteState = getFavoriteState()

// build:
Stack({ alignContent: Alignment.TopEnd }) {
  Column() { /* 商品信息 */ }

  // 左上心形：用 position 绝对定位
  Text(this.favorite.has(this.product.id) ? '♥' : '♡')
    .fontSize(16)
    .fontColor(this.favorite.has(this.product.id) ? this.theme.danger : Color.White)
    .position({ x: 8, y: 8 })
    .onClick(() => this.favorite.toggle(this.product.id))

  // 右上 tag：跟随 Stack 默认 TopEnd 对齐
  if (this.product.tag) { Text(this.product.tag) }
}
```

为什么用 `.position()` 不用 `.align()`？这是这次的另一个坑：

| 写法 | 效果 |
|---|---|
| `Stack({ alignContent: TopEnd })` 容器默认 | 所有子组件按 TopEnd 摆 |
| 子组件加 `.align(Alignment.TopStart)` 想自己摆 | **在某些 ArkUI 版本下失效**，仍然按容器默认 |
| 子组件加 `.position({ x, y })` 绝对定位 | 100% 生效，组件脱离布局流 |

具体表现：第一次写的 `Stack()` 没传 alignContent + 子组件 `.align(TopStart)` / `.align(TopEnd)`，心形和 tag 全部跑到了卡片中间。修复：**Stack 设回 TopEnd（让 tag 走默认对齐），心形改用 position 绝对定位**。

**ProductDetailPage**（详情页 NavBar 右上角心形）：

```typescript
Row() {
  Text('←').padding(12).onClick(() => HMRouterMgr.pop())
  Text('商品详情')
  Blank()

  Text(this.favorite.has(this.vm.product.id) ? '♥' : '♡')
    .fontSize(22)
    .fontColor(this.favorite.has(this.vm.product.id) ? this.theme.danger : this.theme.textSecondary)
    .padding(12)
    .onClick(() => this.favorite.toggle(this.vm.product.id))
}
```

NavBar 是 Row，position 不适用，直接放在 Blank 后面，由 Row 自然把它推到最右。这就是为什么详情页的心形没踩 Stack 那个坑。

---

## 四、OrderState：第三份 PersistenceV2 范本（嵌套对象数组）

### 4.1 数据建模

```typescript
// models/orderModel.ets
export class OrderItem {
  productId: string = ''
  name: string = ''       // ★ 冗余冗余冗余 —— 商品上下架后历史订单也能正确显示
  price: number = 0       // ★ 同上，下单时的价格快照
  image: string = ''
  count: number = 0
}

export class Order {
  id: string = ''
  status: string = 'unpaid'    // 'unpaid' / 'paid' / 'cancelled'
  totalAmount: number = 0
  totalCount: number = 0
  createTime: number = 0
  items: OrderItem[] = []
}
```

**核心设计决策**：OrderItem 不持有 Product，而是**冗余字段（name / price / image）下单时的快照**。
这是 e-commerce 的强约束：商品改价 / 下架 / 删除后，**历史订单上的显示必须是下单时刻的样子**，否则用户看到订单金额对不上会炸锅。

### 4.2 OrderState 用 @Type 还原嵌套类原型

```typescript
@ObservedV2
export class OrderState {
  @Trace @Type(Order) orders: Order[] = []

  get unpaidCount(): number {
    return this.orders.filter((o) => o.status === 'unpaid').length
  }

  create(order: Order): void {
    const next = this.orders.slice()
    next.unshift(order)      // 最新订单排前
    this.orders = next
  }

  markPaid(id: string): void {
    this.orders = this.orders.map((o) => {
      if (o.id === id) {
        o.status = 'paid'
      }
      return o
    })
  }
  // ...
}

export function getOrderState(): OrderState {
  return PersistenceV2.connect(OrderState, 'OrderState', () => new OrderState())!
}
```

`@Type(Order)` 装饰器告诉 PersistenceV2：**反序列化时把每个对象 `new Order()` 还原原型**。如果不加，下次启动 App 读出来的 `orders[0]` 是普通 `{}` 对象，丢失 Order 类的方法和原型链。

> CartState 里的 `@Trace @Type(Product) items` 是同一套用法。两次出现就是范本了 —— 记住这条：**`@ObservedV2` 类的字段只要是另一个类的实例数组，几乎一定要 `@Type` 装饰。**

> 📖 @Type 装饰器：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-type

### 4.3 OrderBiz：从购物车生成订单 + 模拟支付

```typescript
export class OrderBiz {
  private orderState: OrderState = getOrderState()

  createFromCart(cart: CartState): Order {
    const grouped = cart.getGrouped()   // 把 cart.items 按 id 合并

    const order = new Order()
    order.id = `O${Date.now()}`
    order.createTime = Date.now()
    order.status = 'unpaid'
    order.totalCount = cart.totalCount
    order.totalAmount = cart.totalAmount

    const items: OrderItem[] = []
    for (const g of grouped) {
      const item = new OrderItem()
      item.productId = g.product.id
      item.name = g.product.name
      item.price = g.product.price
      item.image = g.product.image
      item.count = g.count
      items.push(item)
    }
    order.items = items

    this.orderState.create(order)
    return order
  }

  pay(orderId: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      setTimeout(() => {
        this.orderState.markPaid(orderId)
        resolve(true)
      }, 800)
    })
  }
}
```

`pay()` 用 `setTimeout` 模拟服务端确认延迟。后期真接服务端时只需替换为 `HttpUtil.post('/api/pay', { orderId })`，上层不动 —— 这就是 biz 分层的价值。

---

## 五、支付流程串通：Checkout → 订单列表

```text
购物车页（CartPage）
  └─ 点"去支付" → HMRouterMgr.push(PAGE_CHECKOUT)
                    ↓ 被 AuthInterceptor 拦截（未登录弹登录对话框）
                    ↓
CheckoutPage
  └─ aboutToAppear → controller.initOrder()
                      ↓ OrderBiz.createFromCart(cart)
                      ↓ 写入 OrderState（status: 'unpaid'）
                      ↓ vm.order = newOrder
  └─ 点"立即支付" → controller.pay()
                      ↓ vm.paying = true
                      ↓ await biz.pay(orderId)         ← setTimeout 800ms 模拟
                      ↓ orderState.markPaid(orderId)
                      ↓ cart.clear()                   ← ★ 清空购物车
                      ↓ promptAction.showToast('支付成功')
                      ↓ HMRouterMgr.replace(PAGE_ORDER_LIST)   ← ★ replace 不是 push
```

### 5.1 为什么用 replace 不用 push

如果用 `push`：导航栈变成 `Cart → Checkout → OrderList`，用户点返回会回到 Checkout，但 cart 已经清空，会触发 Checkout 的"空状态"。体验割裂。

用 `replace`：栈变成 `Cart → OrderList`，用户点返回到 Cart（空），再返回到首页。流程顺。

> 📖 HMRouter push / replace / pop：https://gitee.com/hadss/hmrouter

### 5.2 OrderListPage 的状态徽章

```typescript
statusColor(status: string): ResourceColor {
  if (status === 'paid') return '#52C41A'
  if (status === 'cancelled') return this.theme.textTertiary
  return this.theme.primary    // unpaid
}

statusLabel(status: string): string {
  if (status === 'paid') return '已支付'
  if (status === 'cancelled') return '已取消'
  return '待支付'
}
```

仅 unpaid 状态显示"取消 / 去支付"两个按钮，paid 和 cancelled 都只展示。

---

## 六、最难的坑：ArkUI V2 `@Builder` 边界吃响应式

这个坑值得单独开一节，因为踩了 **3 次**才修对。

### 6.1 现象

我的 Tab 上"我的订单 / 我的收藏"两个菜单右侧要显示数字红点角标，跟随 OrderState / FavoriteState 变化实时更新。代码大致这样：

```typescript
@Local favorite: FavoriteState = getFavoriteState()
@Local orderState: OrderState = getOrderState()

@Builder
badgeMenuRow(label: string, badge: number, action: () => void) {
  Row() {
    Text(label)
    Blank()
    if (badge > 0) { Text(`${badge}`).backgroundColor(this.theme.danger) }
    Text('>')
  }.onClick(() => action())
}

build() {
  // ...
  this.badgeMenuRow('我的订单', this.orderState.unpaidCount, () => this.controller.goOrderList())
  this.badgeMenuRow('我的收藏', this.favorite.totalCount, () => this.controller.goFavoriteList())
}
```

**期望**：心形点击后 favoriteIds 数组变化，角标实时刷新。

**实际**：首次进我的 Tab 时角标正确（比如 1）；切回首页继续收藏到 4 个；切回我的 Tab —— **角标仍然是 1**。只有重启 App 才看到正确的 4。

### 6.2 三次失败的尝试

| 尝试 | 写法 | 结果 |
|---|---|---|
| ① | 把 `this.favorite.totalCount` 传给 `@Builder` 参数 | ❌ |
| ② | 改成直接读字段 `this.favorite.favoriteIds.length` 传给 `@Builder` 参数 | ❌ |
| ③ | `@Monitor('favorite.favoriteIds')` 同步到本地 `@Local count: number`，build 读本地字段 | ❌ |

明明 HomeTabComp 的购物车角标用一模一样的 `this.cart.totalCount` 写法就能 work，差异在哪？

### 6.3 根因：@Builder 是独立 render scope

ArkUI V2 的依赖追踪基于 Proxy `get` 拦截。当 `build()` 执行时，访问 `@Trace` 字段会被收集到**当前正在 render 的组件 scope** 上。

**关键差异**：

```typescript
// HomeTabComp 购物车角标 —— 工作正常 ✅
build() {
  // 直接在 build 顶层访问
  if (this.cart.totalCount > 0) { Text(`${this.cart.totalCount}`) }
}

// ProfileTabComp 角标 —— 失效 ❌
build() {
  // 通过 @Builder 参数传递
  this.badgeMenuRow('我的收藏', this.favorite.totalCount, ...)
}

@Builder
badgeMenuRow(label: string, badge: number, action: () => void) {
  if (badge > 0) { Text(`${badge}`) }   // ← badge 是 number 字面量，没有依赖
}
```

**`@Builder` 是一个独立的 render scope**。参数传给它时，`this.favorite.totalCount` 在 `build()` 上下文中 evaluation 出一个数字，但这个数字塞给 `badge: number` 参数后，**依赖关系跟着参数一起脱离 `build()` scope，进入 `@Builder` 的 scope**。而 `@Builder` 内部用的是字面 `badge` 不是响应式访问，所以下一次 favoriteIds 变化时 `@Builder` 不会重 render。

### 6.4 修法：完全内联到 build 顶层

```typescript
build() {
  // ...
  Column() {
    // ─ 我的订单（完全内联，照搬购物车角标模式）─
    Row() {
      Text('我的订单')
      Blank()
      if (this.orderState.unpaidCount > 0) {
        Text(`${this.orderState.unpaidCount}`)
          .backgroundColor(this.theme.danger)
      }
      Text('>')
    }
    .onClick(() => this.controller.goOrderList())

    // ─ 我的收藏 ─
    Row() {
      Text('我的收藏')
      Blank()
      if (this.favorite.totalCount > 0) {
        Text(`${this.favorite.totalCount}`)
      }
      Text('>')
    }
    .onClick(() => this.controller.goFavoriteList())

    // ─ 无响应式依赖的菜单仍走 @Builder ─
    this.plainMenuRow('消息记录', () => this.controller.goHistory())
    this.plainMenuRow('帮助与反馈', () => {})
    this.plainMenuRow('关于', () => {})
  }
}
```

重新编译，角标立即实时同步。

### 6.5 两条铁律（记到肌肉里）

> 🔥 **铁律 1**：响应式数据流的"消费端"必须在 `@ComponentV2.build()` 顶层访问，**不要经过 `@Builder` 参数中转**。
>
> 🔥 **铁律 2**：`@Builder` 只装"无响应式依赖"的纯展示模板（参数全是 string / 静态 number / 回调），用于代码收敛。

判断标准很简单：**这个 @Builder 内的 UI 会不会因为外部状态变化而需要刷新？** 会 → 不要用 @Builder。

### 6.6 反思：为什么 HomePage 的 `@Provider() theme: ThemeState` 没问题

熟练以后会发现 ArkUI V2 里还有别的"绕一层"的写法是 work 的，比如 `@Provider / @Consumer` 跨组件传递。差异在哪？

`@Provider / @Consumer` 是 V2 内置的**实例引用透传**机制 —— 子组件拿到的就是同一个 `@ObservedV2` 实例，子组件 build 里读 `@Trace` 字段直接建立依赖。整个链路上响应式追踪是连通的。

`@Builder` 不一样，它传的是 evaluation 后的字面值，本质上等同于"把 number 当成 props 传"，**没有响应式连接**。

**结论**：要让 ArkUI V2 响应式工作，宁愿把 `@ObservedV2` 实例引用透传出去（`@Provider / @Consumer` / `@Local` 拿单例），也别把 evaluation 后的字面值往 `@Builder` 里塞。

---

## 七、关键文件清单（带链接，方便日后回查）

```text
server/
  └─ app/api/products/route.ts            ★ 新接口
common/src/main/ets/
  ├─ constants/ApiConstants.ets           PRODUCTS
  └─ utils/HttpUtil.ets                   get<T>
entry/src/main/ets/
  ├─ models/
  │   ├─ productModel.ets                 Product（去掉 MOCK）
  │   └─ orderModel.ets                   Order / OrderItem ★
  ├─ imp/ProductImp.ets                   ★
  ├─ biz/
  │   ├─ ProductBiz.ets                   ★
  │   └─ OrderBiz.ets                     ★
  ├─ viewmodel/
  │   ├─ HomeViewModel.ets                products/loading/error
  │   ├─ FavoriteState.ets                ★ PersistenceV2 范本 #2
  │   ├─ OrderState.ets                   ★ PersistenceV2 范本 #3（@Type）
  │   ├─ CheckoutViewModel.ets            ★
  │   └─ FavoriteListViewModel.ets        ★
  ├─ controller/
  │   ├─ HomeController.ets               loadProducts
  │   ├─ CartController.ets               goPay 改跳 Checkout
  │   ├─ ProfileController.ets            +goOrderList +goFavoriteList
  │   ├─ CheckoutController.ets           ★
  │   ├─ OrderListController.ets          ★
  │   └─ FavoriteListController.ets       ★
  ├─ pages/
  │   ├─ ProductDetailPage.ets            NavBar 加心形
  │   ├─ CheckoutPage.ets                 ★
  │   ├─ OrderListPage.ets                ★
  │   └─ FavoriteListPage.ets             ★
  ├─ components/
  │   ├─ HomeTabComp.ets                  aboutToAppear+三态分支
  │   ├─ ProductCardComp.ets              左上心形（position 定位）
  │   └─ ProfileTabComp.ets               ★ 我的订单/我的收藏（内联）
  └─ constants/EntryRoutes.ets            +3 个常量
```

---

## 八、考点 Q&A（写给将来面试 / 复盘的自己）

### Q1：PersistenceV2 持久化一个对象数组，关键装饰器是什么？为什么？

**A**：`@Trace @Type(SomeClass) items: SomeClass[] = []`。

- `@Trace`：字段变化时通知 V2 系统触发 render
- `@Type(SomeClass)`：反序列化时把每个 plain object `new SomeClass()` 还原原型，否则下次启动读出来是 `{}` 普通对象，丢失类方法和 instanceof 检查

### Q2：为什么 `FavoriteState.toggle` 用 `this.favoriteIds = next` 而不是 `this.favoriteIds.push(id)`？

**A**：V2 的 `@Trace` 对**整体替换**100% 触发响应；对**原地 mutation**（push / splice）在不同 ArkUI 版本下表现不一致。为了写得稳，**永远用整体替换**：

```typescript
const next = this.favoriteIds.slice()  // 浅拷贝
next.push(id)
this.favoriteIds = next                // 整体替换 —— 必触发响应
```

### Q3：为什么 OrderItem 要冗余 name / price / image，而不是只存 productId？

**A**：电商行业惯例。商品改价 / 下架 / 删除后，**历史订单上的显示必须是下单时刻的样子**。如果只存 productId 渲染时反查，价格被改了用户看到订单金额变了会炸。下单时刻的快照是订单的法律凭证。

### Q4：CheckoutController.pay 成功后用 push 还是 replace 跳订单列表？为什么？

**A**：用 `HMRouterMgr.replace`。
- `push` 后栈：`Cart → Checkout → OrderList`，返回回到 Checkout 但 cart 已空，体验割裂
- `replace` 后栈：`Cart → OrderList`，返回回到 Cart（空），再返回首页，流程顺

### Q5：在 ArkUI V2 里，下面两种写法哪种角标会响应式更新？为什么？

```typescript
// 写法 A
build() {
  this.badgeRow('收藏', this.favorite.favoriteIds.length)
}
@Builder
badgeRow(label: string, badge: number) {
  if (badge > 0) Text(`${badge}`)
}

// 写法 B
build() {
  Row() {
    Text('收藏')
    if (this.favorite.favoriteIds.length > 0) {
      Text(`${this.favorite.favoriteIds.length}`)
    }
  }
}
```

**A**：**只有 B 会响应式更新**。

A 写法中 `@Builder` 是独立 render scope，参数 `badge` 是 number 字面量，依赖关系不会从 `build()` scope 穿透到 `@Builder` scope。favoriteIds 变化时 `build()` 重 render 但 `@Builder` 不重 render，所以角标卡在旧值。

B 写法直接在 `build()` 顶层访问 `this.favorite.favoriteIds`，V2 把依赖建到 `build()`，favoriteIds 变化时整个 `build()` 重 render，角标实时刷新。

**铁律**：响应式消费端必须在 `@ComponentV2.build()` 顶层访问，不能经过 `@Builder` 参数中转。

### Q6：Stack 容器里多个子组件想分别落在不同角，怎么做？

**A**：两种主流方案。

**方案 1（推荐）**：Stack 设默认对齐 + 部分子组件用 `position` 绝对定位脱离布局流：

```typescript
Stack({ alignContent: Alignment.TopEnd }) {
  Column() { /* 内容 */ }
  if (tag) Text(tag)                                  // 跟随容器默认 TopEnd
  Text('♡').position({ x: 8, y: 8 }).onClick(...)    // 绝对到左上
}
```

**方案 2**：用 `RelativeContainer` 给每个子组件加 `.id()` + `alignRules`，详情页商品信息卡就是这模式（参考 [14-harmony-shopping.md](./14-harmony-shopping.md) 第五节）。

**坑**：在某些 ArkUI 版本里，Stack 子组件直接加 `.align(Alignment.X)` 想覆盖容器默认对齐 —— **不生效**，子组件仍按容器默认对齐摆放。本次踩过一次。

### Q7：HMRouter 的页面用了 `interceptors: ['AuthInterceptor']`，未登录时点击会发生什么？

**A**：

```text
用户点击「我的订单」
  → HMRouterMgr.push({ pageUrl: PAGE_ORDER_LIST })
  → HMRouter 框架查 OrderListPage 装饰器有 interceptors: ['AuthInterceptor']
  → 按字符串名找全局拦截器表 → 命中 AuthInterceptor 类
  → 调 AuthInterceptor.handle()
      → hasToken() 返回 false
      → HMRouterMgr.push(DIALOG_LOGIN_PROMPT) ← 弹登录对话框
      → return HMInterceptorAction.DO_REJECT ← 拦截原跳转
  → 原跳转被取消，OrderListPage 不会被实例化
```

参考 [11-hmrouter-interceptor-dialog-lifecycle.md](./11-hmrouter-interceptor-dialog-lifecycle.md)。

### Q8：FavoriteListPage 里 `@Provider() theme: ThemeState` 字段名能改成 `themeProvider` 吗？

**A**：**不能**。

V2 的 `@Provider / @Consumer` 按**字段名（alias）**匹配。`ProductCardComp` 用 `@Consumer() theme: ThemeState`，要求祖先组件有一个名字叫 `theme` 的 `@Provider`。

如果改成 `@Provider() themeProvider`，alias 是 `themeProvider`，`ProductCardComp` 找 `theme` 找不到，拿到的是默认值 `new ThemeState()`，导致心形 / 文字颜色全部出错。

写代码时**Provider 字段名 = Consumer 字段名**，是一条死规则。本次踩过一次。

> 📖 @Provider / @Consumer：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-provider-and-consumer

---

## 九、官方文档汇总

| 主题 | 链接 |
|---|---|
| 文档中心总入口 | https://developer.huawei.com/consumer/cn/doc/ |
| ArkTS V2 状态管理总览 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-state-management-overview-V5 |
| @ObservedV2 / @Trace | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-observedv2-and-trace |
| @Type 装饰器 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-type |
| PersistenceV2 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-persistencev2 |
| @Provider / @Consumer | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-provider-and-consumer |
| @Monitor | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-monitor |
| @Builder 装饰器 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-builder |
| Stack 容器 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-stack |
| http 模块 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http |
| HMRouter（开源） | https://gitee.com/hadss/hmrouter |
| Next.js Route Handlers | https://nextjs.org/docs/app/building-your-application/routing/route-handlers |

---

## 十、收尾：这次走完一个真实闭环

到这次提交为止，鸿蒙 Demo 已经具备完整电商闭环：

```text
登录 → 拉真实商品 → 浏览 / 搜索 / 详情 → 收藏 → 加购 → 结算
   ↓
模拟支付 → 订单生成 → 订单列表查看 → 待支付订单可去支付/取消
   ↓
持久化层：CartState / FavoriteState / OrderState / AuthPersist / ThemeState
   全部 PersistenceV2 单例，关 App 重启状态完整恢复
```

PersistenceV2 至此演示了三种典型场景：
- **基础字段**：AuthPersist（string 字段）/ ThemeState（boolean）
- **持有类实例数组**：CartState（Product[]）/ OrderState（Order[]，含嵌套 OrderItem）
- **持有基础类型数组**：FavoriteState（string[]）

ArkTS V2 装饰器演示了：`@ObservedV2`、`@Trace`、`@Type`、`@Local`、`@Param`、`@Event`、`@Consumer`、`@Provider`、`@Monitor`、`@Builder`，再加上 `@ComponentV2`、`@Computed`（虽然这次没用 @Computed，但下次可以试）。

最大的收获是这次踩穿的 `@Builder` 响应式断链坑 —— **响应式数据流的消费端必须在 `@ComponentV2.build()` 顶层访问，不能经过 `@Builder` 参数中转**。这条铁律下次写带角标的 UI 直接套用，不会再卡。
