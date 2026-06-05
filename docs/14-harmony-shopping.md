# 鸿蒙 ArkTS 电商 Demo 闭环复盘：商品列表 → 详情加购 → 全局购物车持久化

> 项目：`MyApplication`
> 模块：`entry`
> 复盘主题：把原来"6 张写死卡片 + setPopParam 计数"的粗糙首页，重构为完整的电商闭环——**商品浏览 / 搜索 / 详情 / 加购 / 全局购物车 / 持久化**，覆盖 ArkTS V2 响应式（@ComponentV2 / @Param / @Event / @ObservedV2 / @Trace / @Local / @Type）、PersistenceV2、RelativeContainer 规则布局、HMRouter 传参等鸿蒙核心知识点。

---

## 一、为什么要做这次重构

之前的首页大致是这个样子：

- 6 张硬编码的商品卡片，全部内嵌在 `HomeTabComp` 里用 `@Builder` 渲染
- 点击商品 → 详情页加 / 减数量 → `HMRouterMgr.setPopParam(count)` → 首页 `onResult` 回调里 `cartCount += addCount`
- 首页顶部角标只是一个**孤立的整数**，没有任何商品快照
- 关 App 重启，购物车清零
- 没有搜索、没有购物车页、没有真实图片

满足不了"一个能演示 ArkTS 真实能力的 Demo"的需求。所以这次围绕**商品 → 购物车**的核心链路重写，目标是：

1. **首页**展示丰富商品列表（搜索 / 真实图 / 标签 / 划线原价 / 销量 / 评分）
2. **商品卡片**拆成独立 `@ComponentV2` 组件，通过 `@Param` / `@Event` 跟父级解耦
3. **详情页**用 `RelativeContainer` 做规则布局，演示 ArkUI 的相对定位能力
4. **全局购物车状态** `CartState` 用 `PersistenceV2 + @Type(Product)` 持久化，关 App 重启购物车还在
5. **购物车页面**支持 +/- 一件一件改、左滑删全部、空状态、底部支付栏
6. **首页角标 / 详情页加购 / 购物车页**三处状态自动同步（全局 CartState 是唯一数据源）

---

## 二、整体架构思路

从一开始就坚持鸿蒙工程里常用的 **Page / ViewModel / Controller** 三层 + 全局响应式状态的搭配：

```text
HomeTabComp                ← 纯 UI（顶部问候 / 搜索 / 商品网格 / 角标）
   ├─ HomeViewModel        ← 仅 searchKeyword（cartCount 已迁全局）
   ├─ HomeController       ← getFilteredProducts / goDetail
   └─ ProductCardComp      ← V2 @Param product / @Event onTap
   
ProductDetailPage          ← 纯 UI（NavBar / 封面 / 信息卡 / 加购调节 / 底部按钮）
   ├─ ProductDetailViewModel  ← product / addCount / lifecycleLog
   └─ ProductDetailController ← initFromParam / initLifecycle / confirmAndBack

CartPage                   ← 纯 UI（NavBar / 空状态 or List / 底部支付）
   └─ CartController       ← increase / decrease / remove / goPay

viewmodel/CartState.ets    ← ★ 全局响应式 + PersistenceV2 持久化
   - items: Product[]      ← @Trace @Type(Product)
   - add / addN / removeOne / remove / clear
   - getGrouped() 实时聚合
   - getCartState() 单例工厂
```

**关键决策**：让 `CartState` 作为唯一数据源，首页角标、详情页加购、购物车页通通围绕它转。这样任何一处变化，其他两处自动响应，不需要手动 propagate。

数据流：

```text
首页 HomeTabComp.cart.totalCount           ← 角标
   ↑
   读
   ↑
[全局] CartState ──→ PersistenceV2 ──→ Preferences 本地存储
   ↑       ↑
   写       写
   ↑       ↑
详情页 cart.addN(product, count)         购物车页 cart.add / removeOne / remove
```

---

## 三、Step 1：数据 Model 与本地图片

### 3.1 扩展 `Product` 字段

原来的 `Product` 只有 `id / name / price / desc / tag`，对一个电商卡片来说**太薄**。补到：

```typescript
export class Product {
  id: string = ''
  name: string = ''
  price: number = 0          // 当前价
  desc: string = ''
  image: string = ''         // 'images/1.png' 形如此
  originalPrice: number = 0  // 原价（用于划线展示折扣感）
  tag: string = ''           // '新品' / '热门' / '推荐' / ''
  rating: number = 0         // 评分 0~5
  sales: number = 0          // 销量
  stock: number = 0          // 库存
}
```

`MOCK_PRODUCTS` 从 6 条扩到 12 条，主题继续围绕鸿蒙书 / 课程。

### 3.2 图片资源策略：rawfile + 动态拼接

鸿蒙资源有两个目录：

| 目录 | 引用 | 适用 |
|---|---|---|
| `resources/base/media/` | `$r('app.media.xxx')` | 系统图标、多语言/多分辨率适配 |
| `resources/rawfile/` | `$rawfile('xxx.jpg')` | 业务数据图，**支持动态路径拼接** |

商品图明显属于"按 id 动态选图"的场景，**所以选 rawfile**：

```
entry/src/main/resources/rawfile/images/1.png
```

`Product.image` 字段存相对路径 `'images/1.png'`，渲染时：

```typescript
Image($rawfile(this.product.image))
```

阶段性占位时，所有商品先复用同一张 1.png——**先跑通比好看重要**，等 UI 稳定再批量换。

> 📖 资源分类与访问：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/resource-categories-and-access-V5>

---

## 四、Step 2：商品卡片组件拆分（V2 父子通信）

### 4.1 为什么要拆

原 `HomeTabComp` 把卡片 UI 内嵌在一个 `@Builder productCard(product)` 里，导致：

- 200+ 行 UI 全堆在一个文件
- 卡片样式跟首页耦合，无法在搜索结果页 / 收藏夹复用
- 子组件级别的样式与状态管理混乱

### 4.2 `@ComponentV2` + `@Param` + `@Event`

ArkTS V2 引入了一套全新的组件 + 装饰器体系。父子组件通信的关键差异：

| 装饰器 | 作用 | 类比 V1 |
|---|---|---|
| `@Param` | 父传子的**单向只读**属性 | `@Prop` |
| `@Event` | 父传子的回调函数 | 直接传 function |
| `@Once` | 配合 @Param，只接收一次初始值 | — |
| `@Local` | 子组件自己的内部状态 | `@State` |
| `@Consumer` / `@Provider` | 跨层级响应式注入 | `@Consume` / `@Provide` |

新建的 `ProductCardComp`：

```typescript
@ComponentV2
export struct ProductCardComp {
  @Param product: Product = new Product()
  @Event onTap: (p: Product) => void = (_p: Product) => {}
  @Consumer() theme: ThemeState = new ThemeState()

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 6 }) {
        Image($rawfile(this.product.image))...
        Text(this.product.name)...
        // 价格 / 评分 / 销量 ...
      }
      // tag 角标（右上角）
      if (this.product.tag) { Text(...) }
    }
    .onClick(() => { this.onTap(this.product) })
  }
}
```

### 4.3 父组件调用：必须是对象字面量

V2 组件调用**不能按位置传参**，必须传一个**对象字面量**，key 与子组件的 `@Param` / `@Event` 字段名一一对应：

```typescript
// ❌ 错的，编译报 'Type has no properties in common with...'
ProductCardComp(product, this.vm.searchKeyword)

// ✓ 对的
ProductCardComp({
  product: product,
  onTap: (p: Product) => { this.controller.goDetail(p) }
})
```

> 📖 @ComponentV2：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-componentV2-V5>
> 📖 @Param：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-param-V5>
> 📖 @Event：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-event-V5>

---

## 五、Step 3：首页改造（搜索 + 角标 + 网格）

### 5.1 顶部栏 + 搜索栏

`HomeTabComp.build` 简化结构：

```text
Column
├─ Row 顶部栏
│   ├─ Column { '你好，xxx' / '欢迎来到精选课程' }
│   ├─ Blank()
│   └─ Stack 购物车角标（点击 push 到 CartPage）
├─ Search { value, placeholder, onChange }
└─ Grid 商品网格（columnsTemplate '1fr 1fr'）
```

`Search` 组件双向绑定 `vm.searchKeyword`：

```typescript
Search({ value: this.vm.searchKeyword, placeholder: '搜索商品 / 教程' })
  .onChange((v: string) => { this.vm.searchKeyword = v })
```

### 5.2 搜索过滤：V2 响应式自动驱动

业务逻辑放 `HomeController.getFilteredProducts()`：

```typescript
getFilteredProducts(): Product[] {
  const kw = this.vm.searchKeyword.trim()
  if (!kw) return MOCK_PRODUCTS
  return MOCK_PRODUCTS.filter(p => p.name.includes(kw) || p.desc.includes(kw))
}
```

Grid 的数据源直接调它：

```typescript
ForEach(
  this.controller.getFilteredProducts(),
  (product: Product) => { GridItem() { ProductCardComp({...}) } },
  (p: Product) => p.id   // ★ keyGenerator 推荐补，V2 下能避免无谓重渲染
)
```

**注意：不需要 `@Monitor`**。V2 下 build 内部访问了 `vm.searchKeyword`（getFilteredProducts 内部用到），自动收集依赖；关键词变化 → build 重跑 → 列表过滤。

我一开始写成了：

```typescript
// ❌ 错误示范
@Monitor('this.vm.searchKeyword')
search() {
  this.controller.getFilteredProducts()  // 调了又不接返回值，等于没用
}
```

两个错：路径不该带 `this.`，更根本的是**根本没必要用 @Monitor**。`@Monitor` 是用来在字段变化时执行"副作用"（自动持久化、自动埋点等），不是用来驱动渲染。

> 📖 @Monitor：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-monitor-V5>

### 5.3 购物车角标：读全局 CartState

```typescript
@Local cart: CartState = getCartState()  // 全局单例

// 角标
if (this.cart.totalCount > 0) {
  Text(`${this.cart.totalCount}`)
    .backgroundColor(this.theme.danger)
    .borderRadius(8)
    .offset({ x: 4, y: -4 })
}
```

详情页加购 → 全局 `CartState.items` 变化 → @Trace 通知 → 角标自动重渲染。**完全不需要 setPopParam / onResult / cartCount 字段**这一套老路。

---

## 六、Step 4：详情页 RelativeContainer 规则布局

### 6.1 为什么用 RelativeContainer

详情页的"商品信息卡"有 6 个元素需要互相对位：

- 价格在左上
- 原价紧贴价格右侧（划线）
- 标签在右上
- 商品名在价格下方
- 元信息（⭐ / 销量 / 库存）在商品名下方
- 描述在元信息下方撑满左右

用嵌套 Column / Row 也能实现，但 `RelativeContainer` 更直观——**每个子元素声明自己的锚点**，符合"规则布局"思维。

### 6.2 核心约定

| 概念 | 说明 |
|---|---|
| 子组件 id | 必须 `.id('xxx')`，否则不参与布局 |
| 容器锚点 | 保留 id `'__container__'` 代表容器自己 |
| `alignRules` | 声明对齐规则：垂直 `top/center/bottom`、水平 `start/middle/end`（也支持 left/right，但 start/end 适配 RTL） |
| `VerticalAlign` | `Top` / `Center` / `Bottom` |
| `HorizontalAlign` | `Start` / `Center` / `End` |

### 6.3 关键陷阱

⚠️ **三个必踩的坑**：

1. **容器高度不能 `'auto'`**——文档明确指出：宽高为 auto 时，子组件以容器为锚点的方向自适应不生效
2. **每个子组件至少要有一个水平 + 一个垂直锚点**，否则会塌缩到中间
3. **不要写循环依赖**——A 锚 B、B 又锚 A 会被忽略并报警告

### 6.4 实战代码片段

```typescript
RelativeContainer() {
  // ① 当前价（左上）
  Text(`¥${this.vm.product.price}`)
    .id('price')
    .alignRules({
      top: { anchor: '__container__', align: VerticalAlign.Top },
      start: { anchor: '__container__', align: HorizontalAlign.Start }
    })

  // ② 原价划线（紧贴 price 右侧）
  if (this.vm.product.originalPrice > this.vm.product.price) {
    Text(`¥${this.vm.product.originalPrice}`)
      .id('origPrice')
      .decoration({ type: TextDecorationType.LineThrough })
      .alignRules({
        bottom: { anchor: 'price', align: VerticalAlign.Bottom },
        start: { anchor: 'price', align: HorizontalAlign.End }
      })
      .margin({ left: 8 })
  }

  // ③ 角标（右上）
  if (this.vm.product.tag) {
    Text(this.vm.product.tag)
      .id('tag')
      .alignRules({
        top: { anchor: '__container__', align: VerticalAlign.Top },
        end: { anchor: '__container__', align: HorizontalAlign.End }
      })
  }

  // ④ 商品名（price 下方）
  Text(this.vm.product.name)
    .id('name')
    .alignRules({
      top: { anchor: 'price', align: VerticalAlign.Bottom },
      start: { anchor: '__container__', align: HorizontalAlign.Start }
    })
    .margin({ top: 12 })

  // ⑤ 元信息（name 下方）
  Text(`⭐ ${this.vm.product.rating}    已售 ${this.vm.product.sales}    库存 ${this.vm.product.stock}`)
    .id('meta')
    .alignRules({
      top: { anchor: 'name', align: VerticalAlign.Bottom },
      start: { anchor: '__container__', align: HorizontalAlign.Start }
    })
    .margin({ top: 8 })

  // ⑥ 描述（meta 下方，撑满左右）
  Text(this.vm.product.desc)
    .id('desc')
    .alignRules({
      top: { anchor: 'meta', align: VerticalAlign.Bottom },
      start: { anchor: '__container__', align: HorizontalAlign.Start },
      end: { anchor: '__container__', align: HorizontalAlign.End }
    })
    .margin({ top: 10 })
}
.width('100%')
.height(180)              // ★ 必须给固定高度
.padding(16)
.backgroundColor(this.theme.surface)
.borderRadius(12)
```

### 6.5 详情页其他改造

- 删除原来用于学习的"路由传参展示"和"生命周期日志"两个区块
- 封面图从灰色占位换成 `Image($rawfile(this.vm.product.image))`
- 加购按钮 `.enabled(addCount > 0 && product.stock > 0)`，库存为 0 时禁用
- 加购数量调节区的 `+ / -` 按钮**必须**用 `ButtonType.Normal + padding(0)`，否则默认 padding 会把内容挤掉（详见踩坑章节）

### 6.6 路由参数怎么取

HMRouter 的路由参数**不是通过 V2 的 `@Param` 自动注入的**——`@Param` 是父子组件通信，路由参数得在详情页里用 `HMRouterMgr.getCurrentParam()` 显式取：

```typescript
// ProductDetailController.ets
initFromParam(): void {
  const param = HMRouterMgr.getCurrentParam()
  if (param) {
    this.vm.product = param as Product
  }
}

// ProductDetailPage.ets
aboutToAppear(): void {
  this.controller.initFromParam()
}
```

刚开始我直接写了 `@Param product: Product`，结果 product 永远是默认 `new Product()`，价格名字全空——这是把"组件通信"和"路由通信"混了。

> 📖 RelativeContainer：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-relativecontainer-V5>

---

## 七、Step 5：全局购物车状态（PersistenceV2 + @Type）

### 7.1 设计哲学：不查重，纯 push，展示时聚合

最初我考虑过 `Map<productId, count>` 的方案，但发现：

1. `Map` 在 PersistenceV2 里**不可序列化**（必须转成数组）
2. 需要查重逻辑（已存在 → count++，不存在 → 新增）
3. 同 id 的多种"加购形态"（不同时间、不同来源）丢失

最终方案极简：

> **`items: Product[]`，加购就 push（不查重），展示时按 productId 聚合。**

```typescript
@ObservedV2
export class CartState {
  @Trace @Type(Product) items: Product[] = []

  get totalCount(): number { return this.items.length }
  get totalAmount(): number { return this.items.reduce((s, p) => s + p.price, 0) }

  add(p: Product): void { this.items.push(p) }
  addN(p: Product, n: number): void { for (let i = 0; i < n; i++) this.items.push(p) }
  removeOne(id: string): void { /* splice 第一个匹配 */ }
  remove(id: string): void { this.items = this.items.filter(p => p.id !== id) }
  clear(): void { this.items = [] }

  // 展示用聚合：相同 id 合并成 { product, count }
  getGrouped(): GroupedCartItem[] { /* Map 实时聚合 */ }
}

export function getCartState(): CartState {
  return PersistenceV2.connect(CartState, 'CartState', () => new CartState())!
}
```

### 7.2 `@Type(Product)` 是什么

`PersistenceV2` 把状态序列化到本地存储时，对数组里装的"普通对象"是无能为力的——反序列化后会变成 plain object，**丢失类型信息**（如果 Product 上有方法、有 getter，这些都没了）。

`@Type(Product)` 装饰器告诉框架：

> "这个字段的数组元素是 Product 类，反序列化时还原成 Product 实例。"

写法：

```typescript
@Trace @Type(Product) items: Product[] = []
```

一行装饰器，复杂度可控。

> 📖 PersistenceV2：<https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/quick-start/arkts-new-persistencev2.md>
> 📖 @Type：<https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/quick-start/arkts-new-type.md>

### 7.3 单例工厂

```typescript
export function getCartState(): CartState {
  return PersistenceV2.connect(CartState, 'CartState', () => new CartState())!
}
```

任何地方调它都拿到**同一个 CartState 实例**，不需要 @Provider / @Consumer 透传。在响应式组件里用 `@Local cart: CartState = getCartState()` 装一下，UI 就能响应字段变化。

### 7.4 删除语义：`remove` vs `removeOne`

- `removeOne(productId)`：**减一件**（splice 第一个匹配项）—— 购物车页的 `-` 按钮用
- `remove(productId)`：**删除全部**相同 id —— 购物车页左滑出现的红色"删除"按钮用

这跟主流电商体验一致：
- 长按 / 左滑 = 我不要这个商品了
- 点 `-` = 我少买一件

---

## 八、Step 6：购物车页面（List + 聚合 + 左滑）

### 8.1 页面结构

```text
Column
├─ Row NavBar（← 返回 / '购物车' 标题）
├─ if items.length === 0 → Column 空状态（🛒 emoji + '去逛逛' 按钮）
│  else → List
│    └─ ForEach(cart.getGrouped(), item => ListItem { Row { 图 | 名/价 | -/数/+ } }.swipeAction)
└─ Row 底部支付栏（合计 / 件数 / '去支付' 按钮）
```

### 8.2 聚合展示

```typescript
ForEach(this.cart.getGrouped(), (item: GroupedCartItem) => {
  ListItem() {
    Row({ space: 12 }) {
      Image($rawfile(item.product.image)).width(80).height(80)
      Column { Text(item.product.name); Text(`¥${item.product.price}`) }.layoutWeight(1)
      Row { 
        Button('-').onClick(() => this.controller.decrease(item.product.id))
        Text(`${item.count}`)
        Button('+').onClick(() => this.controller.increase(item.product))
      }
    }
  }
  .swipeAction({ end: this.deleteBuilder(item.product.id) })
}, (item: GroupedCartItem) => item.product.id)
```

注意 `item.product` 是 Product 实例（拜 `@Type(Product)` 所赐），所以 `increase` 直接传 `item.product` 进去 `cart.add()` 即可。

### 8.3 左滑删除

`ListItem.swipeAction({ end: Builder })`：

```typescript
@Builder
deleteBuilder(productId: string) {
  Row() {
    Button('删除')
      .backgroundColor(this.theme.danger)
      .height(80)
      .onClick(() => this.controller.remove(productId))
  }
  .padding({ left: 12 })
  .height('100%')
}
```

> 📖 ListItemSwipeAction：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-listitem-V5>

---

## 九、闭环串联：一次完整加购的数据流

整个项目最 satisfying 的地方就是 **三处状态自动同步**。一个用户故事走完：

```text
1. 用户在首页搜索 "ArkTS" 
   → HomeViewModel.searchKeyword = 'ArkTS'
   → @Trace 通知 build 重跑
   → ForEach 重算 controller.getFilteredProducts()
   → Grid 只展示匹配商品

2. 点击 "ArkTS 快速入门" 卡片
   → HomeController.goDetail(product)
   → HMRouterMgr.push({ pageUrl, param: product })

3. 详情页 aboutToAppear
   → ProductDetailController.initFromParam()
   → getCurrentParam() → vm.product = product

4. 点 + 三次
   → ProductDetailController.addToCart()
   → vm.addCount: 0 → 1 → 2 → 3
   → @Trace addCount → 加购按钮 label 实时变 "加入购物车（3）"

5. 点 "加入购物车（3）"
   → ProductDetailController.confirmAndBack()
   → cart.addN(product, 3)         ← 全局 CartState push 3 次
   → PersistenceV2 自动序列化到本地
   → HMRouterMgr.pop() 回首页

6. 首页可见
   → @Local cart: CartState 是同一个单例引用
   → cart.totalCount 从 0 → 3
   → @Trace items → 角标自动重渲染显示 "3"

7. 点角标 → 进购物车页
   → CartPage @Local cart = getCartState() 拿到同一个单例
   → cart.items.length > 0 → 走 List 分支
   → cart.getGrouped() → [{ product: ArkTS, count: 3 }]
   → 列表显示 1 行，数量 3

8. 点 - 按钮
   → CartController.decrease(productId)
   → cart.removeOne(id) → splice 第一项
   → @Trace items → ForEach 重算 → count 显示 2，底部合计减一份金额

9. 关 App、重启
   → PersistenceV2 从本地反序列化 → @Type(Product) 把 items 还原成 Product 实例
   → 购物车状态完全恢复
```

**核心**：从头到尾**没有显式 setState / 没有事件总线 / 没有手动 propagate**。整个链路靠 ArkTS V2 响应式 + PersistenceV2 持久化天然 wire 起来。

---

## 十、踩坑总结

### 10.1 V2 组件调用必须用对象字面量

```typescript
ProductCardComp(product, kw)          // ❌ 'Type has no properties in common...'
ProductCardComp({ product, onTap })   // ✓
```

### 10.2 `@Event` 别加 `?` 让它 optional

```typescript
@Event onTap?: (p: Product) => void   // ❌ 调用时还要判空，跟默认 noop 矛盾
@Event onTap: (p: Product) => void = (_p) => {}   // ✓
```

### 10.3 HMRouter 路由参数不是 `@Param`

```typescript
@Param product: Product = new Product()   // ❌ 永远是默认空对象
```

必须 `HMRouterMgr.getCurrentParam() as Product` 在 `aboutToAppear` 里取。

### 10.4 `@Monitor` 的路径不带 `this.`

```typescript
@Monitor('this.vm.searchKeyword')    // ❌
@Monitor('vm.searchKeyword')         // ✓
```

而且大多数情况下**根本不需要 @Monitor**——V2 build 自动收集依赖。@Monitor 留给"字段变化时做副作用"的场景（如自动持久化、自动埋点）。

### 10.5 RelativeContainer 高度必须固定

`'auto'` 时子组件以容器为锚点的方向**自适应失效**。给 `.height(180)` 或被父级 layout weight 撑开。

### 10.6 RelativeContainer 子组件忘记 `.id()`

不参与布局规则，直接被忽略。

### 10.7 Button 小尺寸文字被裁

**这是最隐蔽的一个坑**。默认 `type` 是 `Capsule`（旧 API）或 `ROUNDED_RECTANGLE`（API 18+），**自带较大的内部 padding**。`width(28).height(28).fontSize(16)` 的 "+/-" 按钮文字会被吞掉。

修复：

```typescript
Button('-')
  .type(ButtonType.Normal)   // ★ 关掉胶囊默认样式
  .borderRadius(14)          // ★ 自己控圆角（视觉仍像圆形）
  .padding(0)                // ★ 清掉默认 padding
  .width(28).height(28).fontSize(16)
```

字号大小**不是主因**——padding 才是元凶。

### 10.8 PersistenceV2 + 类对象数组必须 `@Type`

```typescript
@Trace items: Product[] = []                   // ❌ 反序列化后变 plain object
@Trace @Type(Product) items: Product[] = []   // ✓
```

### 10.9 数组改动用赋值新数组，比 splice 更稳

```typescript
// ❌ 有时不触发 V2 重渲染
this.items.splice(idx, 1)

// ✓ 整体赋值新数组，保证 ForEach 重算 keyGenerator
this.items = this.items.filter(p => p.id !== id)
```

### 10.10 ForEach 一定补 keyGenerator

```typescript
ForEach(list, (p) => GridItem() { ProductCardComp({ product: p, ... }) }, (p: Product) => p.id)
//                                                                       ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑
//                                                                       推荐补，避免无谓重渲染
```

---

## 十一、目录结构对照

最终 entry 模块下跟本次重构相关的文件：

```text
entry/src/main/
├─ ets/
│  ├─ pages/
│  │  ├─ CartPage.ets                   ★ 新建：购物车页
│  │  ├─ ProductDetailPage.ets          重写：RelativeContainer 规则布局
│  │  └─ HomePage.ets                   不变（顶层容器）
│  ├─ components/
│  │  ├─ ProductCardComp.ets            ★ 新建：商品卡片（@ComponentV2）
│  │  └─ HomeTabComp.ets                重写：搜索/角标/网格
│  ├─ controller/
│  │  ├─ CartController.ets             ★ 新建：代理 CartState
│  │  ├─ ProductDetailController.ets    改：confirmAndBack → cart.addN
│  │  └─ HomeController.ets             改：删 onResult 回调
│  ├─ viewmodel/
│  │  ├─ CartState.ets                  ★ 新建：全局购物车（PersistenceV2）
│  │  ├─ ProductDetailViewModel.ets     不变
│  │  └─ HomeViewModel.ets              改：删 cartCount，只剩 searchKeyword
│  ├─ models/
│  │  └─ productModel.ets               扩展字段 + MOCK 数据
│  └─ constants/
│     └─ EntryRoutes.ets                加 PAGE_CART 常量
└─ resources/
   └─ rawfile/images/1.png              占位商品图
```

跨模块复用：
- `KeyboardController` 从 `chat/controller/` 提到 `common/utils/`，通过 `common/Index.ets` 暴露给 chat 和 entry 共用

---

## 十二、关键文档链接汇总

ArkTS V2 状态管理：
- @ComponentV2：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-componentV2-V5>
- @Param：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-param-V5>
- @Event：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-event-V5>
- @Local：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-local-V5>
- @ObservedV2 / @Trace：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-observedv2-and-trace-V5>
- @Monitor：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-monitor-V5>
- @Provider / @Consumer：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-provider-and-consumer-V5>

持久化：
- PersistenceV2：<https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/quick-start/arkts-new-persistencev2.md>
- @Type：<https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/quick-start/arkts-new-type.md>
- AppStorageV2：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-appstoragev2-V5>

布局 / 组件：
- RelativeContainer：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-relativecontainer-V5>
- List：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-list-V5>
- ListItem swipeAction：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-listitem-V5>
- Button：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-button-V5>
- Image：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-image-V5>
- Search：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-search-V5>

资源 / 权限：
- 资源分类与访问：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/resource-categories-and-access-V5>

路由：
- HMRouter（HADSS 官方）：<https://gitee.com/hadss/hmrouter>

---

## 十三、下一步可以做什么

这次只跑通了"加购"的核心闭环。后面可以继续完善：

1. **支付页 / 订单页**：现在 `goPay` 只弹 Toast，可以做真实的订单流
2. **收藏功能**：跟 CartState 同款套路，再来一个 `FavoriteState`
3. **商品详情页轮播图**：单图改成 Swiper + 多张
4. **首页分类 / 推荐 Tab**：把现有的"商品网格"升级成"分类 + 推荐"两段式
5. **下拉刷新 + 上拉加载更多**：List 接 `Refresh` 组件
6. **真实接口**：MOCK_PRODUCTS 替换为 `/api/products` 真实请求（项目里已有 HttpUtil）
7. **搜索历史 + 热门搜索**：搜索框点击展开历史词
8. **网络图片切换**：把本地 1.png 占位换成网络 URL（已经预留了 `image.startsWith('http')` 兼容判断点）

---

## 十四、自测六问

学完这次重构，你应该能答出下面六道题。每道题对应今天踩过的一个真实坑或一个关键机制。建议合上博客先自己答，答完再看下面的标准答案。

### 第 1 题：V2 组件调用语法

**题目**：
你写了一行：

```typescript
ProductCardComp({
  product: product,
  onTap: (p: Product) => { this.controller.goDetail(p) }
})
```

如果改成 `ProductCardComp(product, this.controller.goDetail)`，编译器会怎么报错？背后真正的原因是什么？

**标准答案**：

- **报错原文**：

```
Type 'Product' has no properties in common with type
'{ readonly product?: Product; onTap?: ...; theme?: ThemeState }'
```

翻译：你给的 Product 类型，跟期望的属性对象**没有任何共同属性**。

- **真正原因**：
  - V2 组件调用规范要求传**一个对象字面量**，key 对应组件里的 `@Param` / `@Event` 字段名
  - TS 把第一个参数 `product`（Product 类型）当成"属性对象"去匹配 `{ product?, onTap?, theme? }`
  - Product 类自身字段是 `id / name / price / image...`，**没有** `product / onTap / theme` 这三个
  - 所以"无共同属性"

- **加分点**：第二个参数 `this.controller.goDetail` 即使语法允许，**this 也会丢**——必须用箭头函数 `(p) => this.controller.goDetail(p)` 保住外层 this。

- **常见错误**：把"对象字面量"说成"字面量类型"。后者是 TS 里 `'red' | 'green'` 这种取值受限的类型，跟这里完全两回事。

---

### 第 2 题：V2 响应式机制

**题目**：
HomeTabComp 里**没写任何 `@Monitor`**，但搜索框输入文字后 Grid 会自动过滤。从用户敲键盘到 Grid 重渲染，中间发生了什么？关键的"自动"在哪里？

**标准答案**：

```text
1. 用户敲键盘
2. Search.onChange(v) 触发
3. this.vm.searchKeyword = v          ← 写 @Trace 字段
4. @Trace 通知响应式系统:"这字段变了"
5. 响应式系统查依赖图:谁读过它?
6. 找到 build 中 → controller.getFilteredProducts() → 内部读了 vm.searchKeyword
7. 标记 build 需要重跑
8. build 重跑 → 重新调用 getFilteredProducts() → 返回新数组
9. ForEach 拿新数组 + keyGenerator diff → 增删 GridItem
10. Grid 渲染更新
```

**两个"自动"的本质**：

| 自动行为 | 发生时机 | 机制 |
|---|---|---|
| **依赖收集** | build 第一次跑时 | build 里**只要读了 @Trace 字段**（哪怕嵌套在 controller 方法里），就自动建依赖 |
| **依赖通知** | @Trace 字段被写入时 | 自动通知所有依赖此字段的 build 重跑 |

V2 跟 V1 最大的区别：

- V1：改 state → 触发 setState → UI 重渲染（**事件驱动**）
- V2：**读 = 订阅，写 = 通知**（**依赖追踪**）

**常见错误**：把响应式理解成 V1 思路——以为是"改 vm.list → UI 重渲染"。V2 下 `getFilteredProducts()` 是个纯函数，不接受参数也不更新 vm，每次 build 现算。"vm 里有过滤后的列表"是想象出来的字段。

---

### 第 3 题：PersistenceV2 + @Type

**题目**：

```typescript
@Trace @Type(Product) items: Product[] = []
```

去掉 `@Type(Product)` 后，关 App 重启再访问 `items[0].id` 怎样？访问 Product 类方法（假设以后加上的方法）又怎样？

**标准答案**：

| 行为 | 加 `@Type(Product)` | 不加 `@Type` |
|---|---|---|
| 持久化写盘 | ✓ 成功 | ✓ **也成功** |
| 反序列化 | items[0] 是 Product 实例 | items[0] 是 plain object |
| `items[0].id` | ✓ '001' | ✓ **'001'，照样能拿到** |
| `items[0] instanceof Product` | ✓ true | ✗ false |
| `items[0].someMethod()` | ✓ 能调 | ✗ **TypeError: not a function** |

**关键认知**：

- `@Type` 不是"开关"，是"反序列化的类型提示标签"
- 加了：框架自动 `new Product() + 填字段` → 真 Product 实例（恢复方法和 instanceof）
- 不加：plain object（**不报错**，能跑，但丢方法和 instanceof）

**最坑的地方**：今天忘加，过几个月给 Product 加方法那天突然崩——**重启前的旧数据触发崩溃，重启后的新数据没事**，定位非常痛苦。

**一句话记忆**：JSON 能存数据，存不下类型。`@Type` 是用来"还原类型"的，不是用来"开启持久化"的。

**常见错误**：以为"不加 @Type 就报错"。实际**不报错**才是这道题最大的坑。

---

### 第 4 题：HMRouter 路由参数 vs `@Param`

**题目**：
详情页想拿首页 `push` 时传的 product，为什么不能写：

```typescript
@Param product: Product = new Product()
```

① 运行时 `this.product` 是什么？② 为什么 @Param 不能接路由参数？③ 正确写法？

**标准答案**：

**①** `this.product` 永远是默认空对象——所有字段是初始值（空字符串、0）。因为详情页不是被父组件以 `<ProductDetailPage product={...} />` 形态实例化的，@Param 拿不到任何输入。

**②** 两套机制完全独立：

| @Param（组件通信） | HMRouter param（路由传参） |
|---|---|
| 父组件实例化子组件时通过对象字面量传入 | HMRouterMgr.push 时塞进路由栈 |
| 跟"组件树父子关系"绑定 | 跟"导航历史栈"绑定 |
| 子组件 build 时框架自动注入 | 目标页要主动调 getCurrentParam 取 |

详情页是被路由 push 出来的**独立页面**，跟首页是"导航关系"不是"父子嵌套关系"。**名字都叫 param 是巧合**。

**③** 正确写法：

```typescript
aboutToAppear(): void {
  const param = HMRouterMgr.getCurrentParam()  // 取出来是 Object | undefined
  if (param) {
    this.vm.product = param as Product          // ① 强转 ② 写入 vm
  }
}
```

三步：

- **取**：`HMRouterMgr.getCurrentParam()`（类名带 Mgr 后缀，方法名驼峰）
- **强转**：`as Product`（V2 不会自动推断路由参数类型）
- **写入 vm**：让响应式接管后续 UI 渲染

**生命周期**：必须在 `aboutToAppear()` 里调，在 build 之前。

---

### 第 5 题：RelativeContainer 锚点

**题目**：
详情页"商品信息卡"右上角的 `tag` 子元素（"新品"角标）。

- 用一句话描述它的 `alignRules` 锚点关系
- 如果忘记给它 `.id('tag')` 会怎样？

**标准答案**：

**一句话**："top 锚到 `__container__` 的 Top，end 锚到 `__container__` 的 End。"

代码：

```typescript
Text(this.vm.product.tag)
  .id('tag')
  .alignRules({
    top: { anchor: '__container__', align: VerticalAlign.Top },
    end: { anchor: '__container__', align: HorizontalAlign.End }
  })
```

**忘记 `.id()` 的实际后果**：

| 表象 | 实际行为 |
|---|---|
| 元素本身 | **不会消失**，仍然渲染 |
| alignRules 规则 | **完全失效** |
| 位置 | **塌缩到容器默认位置**（通常左上角 0,0） |
| 控制台 | 可能有警告日志 |

不是"消失"，是"位置失控"——"新品"角标会从右上角跑到左上角，叠在价格 ¥99 上面。视觉上更像 bug 不像消失。

**常见错误**：把 `start/end` 和 `top/bottom` 用反。

- **垂直方向**：`top` / `center` / `bottom` 配 `VerticalAlign.X`
- **水平方向**：`start` / `middle` / `end` 配 `HorizontalAlign.X`
- `start/end` 不能锚"上边"——它们是国际化的 `left/right` 别名

**RelativeContainer 三个必踩坑**：

| # | 坑 | 后果 |
|---|---|---|
| 1 | 容器高度写 `'auto'` | 子组件以容器为锚点的方向自适应失效 |
| 2 | 子组件缺 `.id()` | 不参与规则布局，塌缩到默认位置 |
| 3 | 子组件缺锚点（垂直或水平少一个） | 该方向塌缩到中间 |

---

### 第 6 题：CartState 全局架构

**题目**：
下面这 4 件事都依赖**同一个对象**：

- 首页购物车角标的数字
- 详情页点"加入购物车"
- 购物车页 ± 按钮 / 左滑删除
- 关 App 重启后购物车状态自动恢复

① 这个对象叫什么、在哪个文件？② 用什么 API 拿它？③ 为什么不靠事件总线、不靠 setPopParam/onResult、不靠手动同步就能联动？

**标准答案**：

**①** 类名 **`CartState`**，文件 `entry/src/main/ets/viewmodel/CartState.ets`

**②** 用 **`getCartState()`** 工厂函数：

```typescript
@Local cart: CartState = getCartState()

// 工厂内部：
export function getCartState(): CartState {
  return PersistenceV2.connect(CartState, 'CartState', () => new CartState())!
}
```

注意拼写：`PersistenceV2`（V 大写、不要漏 V2 后缀）。

**③** 三个机制叠加，缺一不可：

```text
首页:     @Local cart = getCartState()  ┐
详情页:   private cart = getCartState() ├─── 三处拿到的是同一个对象引用
购物车页: @Local cart = getCartState()  ┘
                      ↓
            PersistenceV2.connect 用 key 'CartState' 维护全局单例
            第一次调 new + 从盘恢复;后续调返回同一引用
                      ↓
            所以 cart.items.push(p) 任何一处发生,三处都看到变化
                      ↓
            @ObservedV2 + @Trace 让字段变化被自动收集 / 通知
                      ↓
     ↓                    ↓                    ↓
首页 build 重跑       购物车页 build 重跑       PersistenceV2 自动写盘
角标更新              列表更新                 (无需手动 save)
```

三个机制各自的角色：

| 机制 | 作用 | 缺了会怎样 |
|---|---|---|
| **PersistenceV2 = 单例工厂** | 按 key 维护，同 key 拿到同一对象 | 三个页面各拿各的实例，不联动 |
| **@ObservedV2 + @Trace** | 字段变化追踪 | 单例改了，UI 不知道 |
| **依赖收集 = 读 = 订阅** | build 读 @Trace → 自动建依赖 | UI 不会因字段变化重跑 |

---

### 自测打分参考

如果上面 6 道题你能完整答出 4 道以上，说明本次重构的核心机制你都消化了。如果低于 4 道，对照博客对应章节再过一遍：

| 题号 | 复习章节 |
|---|---|
| 第 1 题 | 第 4 章 |
| 第 2 题 | 第 5 章 + 第 10.4 节 |
| 第 3 题 | 第 7 章 + 第 10.8 节 |
| 第 4 题 | 第 6.6 节 |
| 第 5 题 | 第 6.2 + 6.3 节 |
| 第 6 题 | 第 7 章 + 第 9 章 |

### 六个最容易栽的认知误区（汇总）

1. **V2 组件调用 ≠ 函数位置参数**：必须对象字面量，key 对应 @Param/@Event
2. **响应式 ≠ 事件回调**：V2 是"读=订阅，写=通知"，不是"改 state → setState → 重渲染"
3. **@Type ≠ 持久化开关**：不加不报错，但丢方法和 instanceof，是延迟暴露的坑
4. **HMRouter param ≠ @Param**：两套独立机制，名字相同是巧合
5. **start/end ≠ top/bottom**：start/end 是水平方向（left/right 的国际化别名）
6. **CartState 联动 ≠ 事件广播**：靠的是"单例 + @Trace + 依赖收集"三件套，缺一不可

---

## 十五、写在最后

这次重构最大的收获不是某个具体的 API，而是体会到了 **ArkTS V2 响应式 + PersistenceV2 持久化** 这两套机制是怎么自然 wire 在一起的。

只要：

- 全局状态用 `@ObservedV2` + `@Trace`
- 通过 `PersistenceV2.connect` 拿单例
- 在组件里用 `@Local` 接住引用
- 类对象数组别忘 `@Type`

整个数据流就**不需要事件总线、不需要 setPopParam 回调、不需要手动 propagate**。任何地方写一下，所有读它的地方自动响应。这跟 React + Zustand / Vue + Pinia 给我的体验是一模一样的——区别只是装饰器名字。

而且鸿蒙最让我觉得"省心"的一点：**持久化跟响应式是一套话语体系**。在 PersistenceV2.connect 后的对象上 `cart.items.push(...)`，你**完全感觉不到自己在写文件存储**，UI 和磁盘同步发生。这是过去 SharedPreferences / Realm / Room 时代很难有的体验。
