# 鸿蒙首页从等高商品 Grid 到双列瀑布流：同一张图也能做出小红书式浏览节奏

> 项目：`harmony-chat-demo`
>
> 模块：`entry`（HarmonyOS 前端）+ `server`（Next.js mock API）
>
> 本文代码：课程商品首页。**不改业务含义**，仍然保留商品详情、价格、购物车和收藏；只把“整齐但单调的两列商品网格”升级为“封面、文案高度错落的双列瀑布流”。

很多 Demo 的首页一开始都是这个形态：两列 `Grid`，每张卡片同样高，封面同样高，描述只显示一行。它稳定、好写，但当商品数量一多，视觉上会变成整齐的表格，和内容社区那种“想一直往下刷”的感觉相差很远。

这次改造有一个刻意的限制：**所有课程仍然使用同一张本地图片**。我们只通过后端返回的封面高度和长短不一的文案，做出真实的错落效果。这很适合 Demo：无需先准备一堆素材，也能把瀑布流的完整数据链路和布局思路讲清楚。

---

## 一、先看目标：不是“高度不同的 Grid”，而是两列独立的卡片流

改造前的结构很典型：

```text
Grid（两列）
  ├─ GridItem：商品 1
  ├─ GridItem：商品 2
  ├─ GridItem：商品 3
  └─ GridItem：商品 4
```

如果只给 `GridItem` 内的图片设置不同高度，会发生一个容易忽略的问题：**同一行的高度由最高卡片决定**。矮卡片下面会留下大片空白，它看起来仍然是表格，不是瀑布流。

这次改造成：

```text
Scroll
  └─ Row
      ├─ Column（左列，独立向下生长）
      │   ├─ 商品 1：132vp 封面
      │   ├─ 商品 3：158vp 封面
      │   └─ 商品 5：206vp 封面
      └─ Column（右列，独立向下生长）
          ├─ 商品 2：194vp 封面
          ├─ 商品 4：120vp 封面
          └─ 商品 6：144vp 封面
```

左右列没有共同的“行”概念，所以每一列都会从自己的上一张卡片后面继续排，空白自然消失。这是最容易控制、最适合小型数据集的双列瀑布流实现。

> 它不是复杂的“动态计算最短列再插入”的通用算法；本项目用筛选结果的奇偶下标分列。对于首页 12 条 mock 数据足够直观。数据量很大、支持分页或卡片高度完全不可预估时，再升级成按累计高度分配或虚拟化列表。

---

## 二、数据先行：把视觉差异变成接口契约

瀑布流不是纯前端样式问题。卡片要错落，客户端必须能拿到差异化数据。因此我们给商品接口新增了 `coverHeight`：

```ts
// server/app/api/products/route.ts
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
  coverHeight: number // 新增：封面在首页中占用的高度
}

const MOCK_PRODUCTS: Product[] = [
  {
    id: '001',
    name: 'ArkTS 快速入门',
    desc: '鸿蒙原生开发语言全解析',
    image: 'images/1.png', // 所有条目仍是同一张本地图片
    coverHeight: 132,
    // ...
  },
  {
    id: '002',
    name: 'HarmonyOS 实战',
    desc: '从零到项目上线完整教程，涵盖登录、列表与网络请求。',
    image: 'images/1.png',
    coverHeight: 194,
    // ...
  }
]
```

这里有两个关键点：

1. `coverHeight` 是内容数据的一部分，而不是在组件里用 `id % 3` 临时猜出来。后续接真实后端时，图片宽高、裁切策略或内容运营配置都可以在服务端统一控制。
2. `desc` 也故意设计成长短不一。封面高度不同只是第一层，标题和摘要的行数差异会让卡片更自然。

鸿蒙侧的模型必须同步扩展，否则网络请求即使成功，UI 也读不到规范字段：

```ts
// entry/src/main/ets/models/productModel.ets
export class Product {
  id: string = ''
  name: string = ''
  // ...原有字段
  coverHeight: number = 140 // 没有返回时的安全默认值
}
```

给默认值的意义是兼容：本地旧缓存、旧接口或手工构造的 `Product` 也不会把图片渲染成 0 高度。

---

## 三、同一张图如何制造不同封面？核心是 Cover 裁切

卡片组件不需要知道图片是否重复，只关心拿到什么路径和什么高度：

```ts
// entry/src/main/ets/components/ProductCardComp.ets
Image($rawfile(this.product.image))
  .width('100%')
  .height(this.product.coverHeight)
  .objectFit(ImageFit.Cover)
  .borderRadius(8)
```

`ImageFit.Cover` 会保持图片比例、填满容器，并裁掉超出的部分。因此，即使 `images/1.png` 是同一张图，132vp、194vp、206vp 的容器也会呈现不同的视觉截面，而不会把图片硬拉伸变形。

摘要从单行改成最多两行：

```ts
Text(this.product.desc)
  .fontSize(11)
  .fontColor(this.theme.textSecondary)
  .maxLines(2)
  .textOverflow({ overflow: TextOverflow.Ellipsis })
```

这样既保留卡片高度的可控边界，又不会因为一段超长简介把整个列表拉得不可预期。

---

## 四、布局实现：`Scroll + Row + 两个 Column`

首页原来使用 `Grid`。现在主区域替换为一个可滚动容器，内部放一个横向 `Row`，再放左右两个独立的 `Column`：

```ts
// entry/src/main/ets/components/HomeTabComp.ets
Scroll() {
  Row({ space: 12 }) {
    Column({ space: 12 }) {
      ForEach(
        this.controller.getFilteredProducts()
          .filter((_p: Product, index: number) => index % 2 === 0),
        (product: Product) => {
          ProductCardComp({
            product: product,
            onTap: (p: Product) => this.controller.goDetail(p)
          })
        },
        (p: Product) => p.id
      )
    }
    .layoutWeight(1)

    Column({ space: 12 }) {
      ForEach(
        this.controller.getFilteredProducts()
          .filter((_p: Product, index: number) => index % 2 === 1),
        (product: Product) => {
          ProductCardComp({
            product: product,
            onTap: (p: Product) => this.controller.goDetail(p)
          })
        },
        (p: Product) => p.id
      )
    }
    .layoutWeight(1)
  }
  .alignItems(VerticalAlign.Top)
  .padding({ left: 16, right: 16, bottom: 16 })
}
.width('100%')
.layoutWeight(1)
.scrollBar(BarState.Off)
```

这里有几处值得拆开说。

### 4.1 为什么外层用 Scroll，而不是把两列放进普通 Column？

首页顶部的问候语和搜索框应该固定在页面上方，只有商品区负责滚动。因此把 `Scroll` 放进外层 `Column` 后，配合 `.layoutWeight(1)` 占据剩余高度，正好实现“顶部不动、内容向下滚”。

### 4.2 为什么两个 Column 都要 `layoutWeight(1)`？

`Row` 里左右列各占 1 份剩余宽度，才能稳定得到等宽双列。不要手写固定宽度，否则横竖屏、不同设备宽度或系统字体变化时都容易溢出。

### 4.3 搜索后还能保持瀑布流吗？

可以。分列的数据源不是原始 `products`，而是 `getFilteredProducts()` 的结果。用户输入关键词后，过滤结果会重新从 0 开始交替分给左右列；商品详情跳转、收藏状态与价格逻辑仍然复用原组件，不需要额外分支。

---

## 五、这次最难处理的 4 个点

### 难点 1：误以为“卡片变高”就等于瀑布流

这是最常见的视觉陷阱。`Grid` 中同一行的两个 `GridItem` 会共享行高，左卡片 120vp、右卡片 200vp 时，左边的 80vp 空白依旧存在。

**处理方式**：移除同一行这个约束，让左右 `Column` 独立垂直排布。只要卡片高度不一致，瀑布效果就自然出现。

### 难点 2：接口、模型与组件必须同时演进

只改服务端会导致 ArkTS 模型没有字段；只改前端模型又会永远走默认高度。完整链路是：

```text
Next.js mock 数据 coverHeight
  → GET /api/products JSON
  → Product.coverHeight
  → ProductCardComp Image.height(...)
  → 双列独立 Column 排布
```

这类 UI 改造最怕“视觉代码写好了，数据没跟上”。因此我们给接口加了一个最小契约测试：

```js
// server/tests/products.contract.test.mjs
test('products API supplies varied cover heights for a waterfall feed', async () => {
  const response = await fetch('http://127.0.0.1:3000/api/products')
  const payload = await response.json()
  const heights = payload.data.map((product) => product.coverHeight)

  assert.ok(heights.every((height) => Number.isInteger(height) && height >= 120))
  assert.ok(new Set(heights).size >= 3)
})
```

它不关心某一张卡片必须是 132vp，而是验证真正的产品约束：所有条目都有合理高度，且列表里至少有三种高度，才会产生瀑布节奏。

### 难点 3：同图复用时要避免拉伸

封面高度变了以后，如果使用拉伸式填充，人物会变胖或变瘦，Demo 看起来反而更廉价。这里必须显式使用 `ImageFit.Cover`：宁可裁切边缘，也不改变原图比例。

正式项目更推荐接口直接返回图片的原始宽高或 `aspectRatio`，前端根据列宽计算高度；本 Demo 用 `coverHeight` 是为了让案例更短、更聚焦。

### 难点 4：两列交替分配不等于严格均衡

`index % 2` 的优点是简单、稳定、搜索后无需额外状态；缺点是如果连续出现几张特别高的卡片，某一列可能比另一列长很多。

下一步可改成“累计高度更短的一列优先放入”的算法：

```text
leftHeight = 0, rightHeight = 0
遍历商品：
  估算 cardHeight = coverHeight + 标题/摘要/价格区域高度
  放入当前更短的列
  更新该列累计高度
```

但要注意：文本实际换行高度会受设备宽度、字体缩放影响，这个算法只能估算。对于需要百万级内容流的产品，应该进一步使用分页、懒加载与虚拟化列表，而不是一次性把所有卡片塞进两个 `Column`。

---

## 六、保持业务不变，比“重写一个首页”更重要

本次没有把课程商品硬改成“笔记”，因为首页的视觉升级不应该破坏既有业务闭环。

| 既有能力 | 改造后状态 |
|---|---|
| 商品搜索 | 仍然通过 `getFilteredProducts()` 工作 |
| 点击卡片进详情 | 仍通过 `onTap → controller.goDetail()` 工作 |
| 左上角收藏 | 仍复用 `FavoriteState` |
| 商品价格、评分、销量 | 继续在卡片内展示 |
| 购物车入口 | 顶部逻辑不变 |

这是做存量页面改版时很实用的原则：**先替换布局容器与展示密度，尽量不要改动已经跑通的事件、状态和导航链路。** 这样视觉升级的回归范围最小。

---

## 七、验证与一个容易混淆的构建问题

本次验证分为两层：

```text
接口层：node --test tests/products.contract.test.mjs
  → products API 返回的高度字段满足瀑布流契约

客户端：Hvigor CompileArkTS
  → ArkTS 组件、布局与模型字段可以通过编译
```

项目里曾遇到完整打包失败，错误分别指向过签名证书过期和命令行环境找不到 `java`。这两类问题发生在**打包/签名阶段**，不能和“首页 ArkTS 代码无法编译”混为一谈。

排查构建问题时建议按阶段判断：

```text
接口测试失败        → 后端数据或接口协议问题
CompileArkTS 失败    → ArkTS 语法、类型、组件布局问题
PackageHap / Sign 失败 → Java、SDK、证书、签名配置问题
```

分层看日志，能避免为了一个签名问题去反复改 UI 代码。

---

## 八、完整改造文件清单

```text
server/
  ├─ app/api/products/route.ts             # mock 数据新增 coverHeight
  ├─ package.json                           # 增加 test:api
  └─ tests/products.contract.test.mjs       # 接口契约测试

entry/src/main/ets/
  ├─ models/productModel.ets                # Product 新增 coverHeight
  └─ components/
      ├─ HomeTabComp.ets                    # Grid → Scroll + Row + 双 Column
      └─ ProductCardComp.ets                # 动态封面高度 + 两行摘要
```

---

## 九、结语：先用内容密度解决“单调”，再扩展社区能力

从等高 Grid 改成双列瀑布流，不需要先上复杂推荐算法，也不需要先准备十二张不同图片。把视觉差异交给数据（`coverHeight`、不同文案长度），把排布从共享行高的 `Grid` 换成独立纵向的双列 `Column`，就能明显提升首页的信息密度和浏览节奏。

后续如果要把这个课程 Demo 再往“小红书式内容社区”推进，可以按这个顺序演进：

```text
双列瀑布流
  → 分页 / 下拉刷新 / 上拉加载
  → 多封面图与真实图片比例
  → 收藏列表与本地持久化
  → 会话卡片、会话详情、继续对话
  → 单用户内容发布与首页排序
```

先把页面“刷起来”，再逐步补数据与互动，Demo 才会从功能集合变成真正有产品感的应用。
