# HarmonyOS 双列瀑布流进阶：估算卡片高度，把内容放入真正更短的一列

> 案例项目：`harmony-chat-demo`
>
> 技术栈：HarmonyOS ArkTS + ArkUI + Next.js Mock API
>
> 目标：把按奇偶下标分列的“伪均衡”升级为按累计预估高度分列，并用 28 条提示词与 AI 助手模板验证滚动效果。

双列 `Column` 能消除 `Grid` 的同行留白，却不代表两列一定均衡。最常见的写法是偶数下标放左列、奇数下标放右列：它保证两列数量接近，但完全不关心每张卡片有多高。一旦同一侧连续分到长图或长文案，页面底部就会出现明显的长短腿。

本文用项目中的真实实现讲清楚三个问题：怎样预估一张 ArkUI 卡片的高度、怎样维护两列累计高度、怎样让加载和搜索都走同一套分列流程。

---

## 一、问题本质：数量均衡不等于高度均衡

原来的分列代码类似这样：

```ts
const left = products.filter((_item, index) => index % 2 === 0)
const right = products.filter((_item, index) => index % 2 === 1)
```

如果四张卡片的高度依次是 `300、150、280、160`，结果是：

```text
左列：300 + 280 = 580
右列：150 + 160 = 310
```

两边都是两张卡片，累计高度却相差 270。真正要优化的目标不是卡片数量，而是每次插入前都选择当前累计高度更短的一列：

```text
初始：left = 0, right = 0
卡片 A 高 300 → 左列，left = 300
卡片 B 高 150 → 右列，right = 150
卡片 C 高 280 → 右列，right = 430
卡片 D 高 160 → 左列，left = 460
```

最终只相差 30，瀑布流底部会自然得多。

---

## 二、本次实现后的文件结构

```text
harmony-chat-demo/
├─ entry/src/main/ets/
│  ├─ components/
│  │  ├─ HomeTabComp.ets          # 只消费左右列并渲染
│  │  └─ ProductCardComp.ets      # 卡片真实可见结构
│  ├─ controller/
│  │  └─ HomeController.ets       # 加载、搜索、触发重新分列
│  ├─ models/
│  │  └─ productModel.ets         # coverHeight + contentType
│  ├─ utils/
│  │  └─ WaterfallLayout.ts       # 纯函数：估高与最短列分配
│  └─ viewmodel/
│     └─ HomeViewModel.ets        # products + leftProducts + rightProducts
└─ server/
   ├─ app/api/products/route.ts   # 28 条提示词 / AI 助手假数据
   └─ tests/
      ├─ waterfall-layout.test.mjs
      └─ products.contract.test.mjs
```

这里最重要的拆分是：组件不计算布局，控制器不重复实现算法，算法文件也不依赖 ArkUI。`WaterfallLayout.ts` 是纯 TypeScript，因此可以用 Node 22.18+ 的原生类型剥离能力直接测试，随后仍由 ArkTS 工程引用。项目在 `server/package.json` 中声明了最低 Node 版本，避免旧版本 Node 无法加载 `.ts`。

---

## 三、第一步：明确“可预估”的卡片结构

卡片真实显示的主要高度来自四部分：

```text
服务端 coverHeight
+ 标题可见行数 × 标题行高
+ 摘要可见行数 × 摘要行高
+ 类型、评分、内边距等固定区域
+ 列内间距
```

对应的最小输入接口只保留算法真正需要的字段：

```ts
export interface WaterfallCardMetric {
  name: string
  desc: string
  coverHeight: number
}
```

不要让工具函数直接依赖完整 `Product`。这样它既能服务当前首页，以后也可以服务会话收藏卡片、笔记流或模板市场。

项目中的估高实现如下：

```ts
const MIN_COVER_HEIGHT: number = 120
const TITLE_CHARS_PER_LINE: number = 10
const DESCRIPTION_CHARS_PER_LINE: number = 15
const TITLE_MAX_LINES: number = 2
const DESCRIPTION_MAX_LINES: number = 3
const TITLE_LINE_HEIGHT: number = 20
const DESCRIPTION_LINE_HEIGHT: number = 17
const CARD_FIXED_HEIGHT: number = 70

function estimateVisibleLines(
  text: string,
  charsPerLine: number,
  maxLines: number
): number {
  const length = Math.max(1, text.trim().length)
  return Math.min(maxLines, Math.max(1, Math.ceil(length / charsPerLine)))
}

export function estimateWaterfallCardHeight(card: WaterfallCardMetric): number {
  const coverHeight = Math.max(MIN_COVER_HEIGHT, card.coverHeight)
  const titleLines = estimateVisibleLines(card.name, 10, 2)
  const descriptionLines = estimateVisibleLines(card.desc, 15, 3)

  return coverHeight +
    titleLines * TITLE_LINE_HEIGHT +
    descriptionLines * DESCRIPTION_LINE_HEIGHT +
    CARD_FIXED_HEIGHT
}
```

这不是像素级测量，而是稳定的布局启发式。中文字符大致按数量估算换行，并用 `maxLines` 限制上限，与 `ProductCardComp` 中标题最多两行、摘要最多三行保持一致。

### 为什么不能只使用 `coverHeight`？

两张封面同高的卡片，标题可能分别占一行和两行，摘要可能分别占一行和三行。如果算法只累计图片高度，视觉上的列高依然会漂移。估算值必须覆盖所有会变化的可见区域。

### 为什么还需要固定高度？

类型标签、免费状态、评分、使用次数、组件 `space` 和上下内边距都占空间。它们不会随数据变化，可以合并为一个固定值。该值不必追求绝对精确，只要所有卡片使用同一套规则，就能正确比较相对高低。

---

## 四、第二步：逐项放入当前更短的一列

结果对象同时记录数组和累计高度：

```ts
export class WaterfallColumns<T extends WaterfallCardMetric> {
  left: T[] = []
  right: T[] = []
  leftHeight: number = 0
  rightHeight: number = 0
}
```

核心算法只有一次线性遍历：

```ts
export function distributeWaterfall<T extends WaterfallCardMetric>(
  cards: T[]
): WaterfallColumns<T> {
  const columns = new WaterfallColumns<T>()

  cards.forEach((card: T) => {
    const estimatedHeight = estimateWaterfallCardHeight(card)
    if (columns.leftHeight <= columns.rightHeight) {
      columns.left.push(card)
      columns.leftHeight += estimatedHeight + 12
    } else {
      columns.right.push(card)
      columns.rightHeight += estimatedHeight + 12
    }
  })

  return columns
}
```

时间复杂度是 `O(n)`，额外空间是两列数组的 `O(n)`。相等时固定优先放左列，可以保证相同输入得到稳定结果，避免刷新后卡片随机换列。

---

## 五、第三步：让 ViewModel 保存“布局结果”

原始数据与布局结果承担不同职责：

```ts
@ObservedV2
export class HomeViewModel {
  @Trace searchKeyword: string = ''
  @Trace products: Product[] = []
  @Trace leftProducts: Product[] = []
  @Trace rightProducts: Product[] = []
  @Trace loading: boolean = false
  @Trace error: string = ''
}
```

- `products` 是接口返回的完整数据源。
- `leftProducts`、`rightProducts` 是当前关键词下的布局投影。
- 搜索不会破坏原始列表，清空关键词后可以立刻恢复全部内容。

控制器统一管理加载和搜索两个入口：

```ts
async loadProducts(): Promise<void> {
  this.vm.loading = true
  this.vm.error = ''
  try {
    this.vm.products = await this.biz.list()
    this.rebuildWaterfall()
  } finally {
    this.vm.loading = false
  }
}

updateSearchKeyword(keyword: string): void {
  this.vm.searchKeyword = keyword
  this.rebuildWaterfall()
}

private rebuildWaterfall(): void {
  const filtered = this.getFilteredProducts()
  const columns = distributeWaterfall(filtered)
  this.vm.leftProducts = columns.left
  this.vm.rightProducts = columns.right
}
```

这一步解决了一个很容易遗漏的问题：搜索结果不能继续沿用初始左右列，否则只能分别过滤两列，无法重新达到高度均衡。正确顺序应当是：

```text
完整数据 → 按关键词过滤 → 从空列重新估高分配 → 更新 UI
```

---

## 六、第四步：组件只负责渲染两列

`HomeTabComp` 不再在 `build()` 中多次调用过滤和 `index % 2`：

```ts
Scroll() {
  Row({ space: 12 }) {
    Column({ space: 12 }) {
      ForEach(this.vm.leftProducts, (product: Product) => {
        ProductCardComp({ product: product })
      }, (product: Product) => product.id)
    }
    .layoutWeight(1)

    Column({ space: 12 }) {
      ForEach(this.vm.rightProducts, (product: Product) => {
        ProductCardComp({ product: product })
      }, (product: Product) => product.id)
    }
    .layoutWeight(1)
  }
  .alignItems(VerticalAlign.Top)
}
```

两个 `Column` 独立向下生长，避免 `Grid` 共享行高造成的留白；`.layoutWeight(1)` 让左右列等宽；外层 `Scroll` 让 28 条内容形成可持续滚动的浏览效果。

卡片展示也从课程商品改为更贴合聊天 Demo 的 AI 内容：

```ts
Text(this.product.contentType === 'assistant' ? 'AI 助手' : '提示词')
Text('免费使用')
Text(`${this.product.sales} 人使用`)
```

标题最多两行、描述最多三行。这两个限制必须与估高常量同步，否则算法认为只显示三行，组件却实际显示五行，误差会随着卡片数量逐渐累积。

---

## 七、假数据怎样设计，才能看出真实效果

这次接口放入 28 条内容，提示词与 AI 助手各占一部分，例如：

- 提示词：把复杂知识讲给小学生、用苏格拉底方式追问、将需求改写为用户故事、把长文章压缩为知识卡片。
- AI 助手：小红书爆款文案助手、旅行规划助手、代码审查搭档、面试模拟官、英语口语陪练。

所有卡片仍使用原 Demo 图片 `images/1.png`，差异来自：

- `coverHeight` 从 120 到 230，且有多种离散高度。
- 标题有一行和两行。
- 摘要有明显长短变化。
- `contentType` 同时包含 `prompt` 与 `assistant`。

服务端用工厂函数统一补齐不变字段：

```ts
function createProduct(seed: ProductSeed): Product {
  return {
    ...seed,
    price: 0,
    originalPrice: 0,
    image: 'images/1.png',
    stock: 999
  }
}
```

这样新增假数据时只写真正有差异的字段，也能从源头保证不会误混入另一张图片。

---

## 八、最难处理的几个点

### 1. 估算高度不等于测量高度

字体缩放、设备宽度、中英文比例都会影响实际换行。当前方案的目标是低成本改善两列平衡，不是实现像素级排版引擎。对于固定两列、限定 `maxLines` 的 Demo，启发式估算足够稳定。

如果未来必须精确，可在卡片首次布局后记录实际高度再重排，但这会引入二次布局和视觉跳动，需要缓存测量结果，并谨慎处理滚动位置。

### 2. 算法参数必须与 UI 同源演进

`TITLE_MAX_LINES = 2`、`DESCRIPTION_MAX_LINES = 3` 对应组件的 `.maxLines(2)` 和 `.maxLines(3)`。以后调整字号、行数或新增可变区域时，应同时更新估高参数和测试。

### 3. 搜索是一条新的布局链路

只在接口加载后分列一次是不够的。搜索后的内容集合已经变化，必须从零重新累计左右高度。本项目由 `updateSearchKeyword()` 统一触发，避免 UI 组件自行修改关键词却忘了更新两列。匹配范围还包含卡片可见的“提示词 / AI 助手”类型标签，保证搜索框提示与真实行为一致。

### 4. `Scroll + 两个 Column` 会一次构建全部卡片

28 条 Demo 数据没有问题。若未来变成几百条真实内容，应增加分页，并评估 ArkUI 的瀑布流 / 懒加载容器或虚拟化方案，避免首次构建过多组件。

---

## 九、用测试守住算法和接口契约

算法测试直接导入生产文件，验证四件事：最短列分配、长文案增高、空数据，以及按“提示词 / AI 助手”可见标签搜索。

```js
test('places each next card into the currently shorter column', () => {
  const result = distributeWaterfall([
    card('a', 220),
    card('b', 100),
    card('c', 100),
    card('d', 100)
  ])

  assert.deepEqual(result.left.map((item) => item.id), ['a', 'd'])
  assert.deepEqual(result.right.map((item) => item.id), ['b', 'c'])
})
```

另外三条分别验证长文案的预估高度更大、空数组返回两个空列，以及中文内容类型标签能够被搜索。

接口契约测试关注内容是否足以支撑瀑布流，而不是绑定某条具体文案：

```js
assert.equal(payload.data.length, 28)
assert.ok(payload.data.every((item) => item.id.startsWith('ai-')))
assert.equal(new Set(payload.data.map((item) => item.id)).size, 28)
assert.ok(new Set(heights).size >= 8)
assert.deepEqual(contentTypes, new Set(['prompt', 'assistant']))
assert.ok(payload.data.every((item) => item.image === 'images/1.png'))
```

验证命令：

```bash
# 纯算法与项目配置测试
cd server
npm test

# 先启动 npm run dev，再在另一终端验证接口
npm run test:api
```

最后还要执行 Hvigor 构建，确保 Node 能运行的纯 TypeScript 同样满足 ArkTS 工程编译要求。

---

## 十、完整数据流回顾

```text
GET /api/products
  → ProductBiz.list()
  → HomeController.loadProducts()
  → vm.products 保存完整数据
  → 关键词过滤
  → estimateWaterfallCardHeight() 预估每张卡片
  → distributeWaterfall() 放入当前更短列
  → vm.leftProducts / vm.rightProducts
  → HomeTabComp 两个独立 Column 渲染
```

真正的思路不是“换一个瀑布流组件”，而是把布局决策拆成可测试的数据变换。页面只渲染结果，搜索和加载复用同一条链路，后端假数据又通过契约测试保证足够多、足够有差异。这样后续接入分页、真实图片比例或会话收藏卡片时，演进路径会清晰很多。
