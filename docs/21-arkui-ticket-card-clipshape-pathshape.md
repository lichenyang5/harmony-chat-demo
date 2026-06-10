# ArkUI 票根卡片：PathShape 真挖洞，shadow 沿凹陷外发光

> 项目：`MyApplication`（AI 助手 demo）
> 组件：`ConfirmTripCardComp`（确认行程卡片）
> 主题：实现"票根 / 车票"效果的卡片 —— 四角圆角 + 左右两个半圆缺口 + 中间撕线 + 阴影。这篇记录我从"色块覆盖出来的假缺口"一路改到"PathShape clipShape 真裁剪"的全过程。

---

## 一、目标长什么样

AI 助手回复"打车"意图时，会下发一张"确认行程"卡片：

- 渐变蓝色抬头（标题 + 起终点 + 距离 / 时长）
- 中段一条横向虚线撕线
- 撕线左右各有一个半圆缺口（票根口）
- 下方白色区：地图、价格区间、选择车型、确认用车按钮
- 整张卡有阴影，缺口处的阴影要"凹"进去，让票根有物理感

效果示意：

```text
┌──────────────────────────────────────────┐
│  确认行程                                 │
│  ─── (黄色高亮)                          │
│                                          │
│  ⊙ 香港中国企业协会          立即出发    │
│  ⋮  全程 34.2 公里      45 分钟          │
│  ⊙ 香港国际机场       预计 13:30 到达    │
└─( - - - - - - - - - - - - - - - - - - )─┘  ← 撕线 + 两侧缺口
│                                          │
│   ┌────────────────────────────────┐    │
│   │            [地图]              │    │
│   └────────────────────────────────┘    │
│   预估 145~155 人民币起   [选择车型]    │
│   已选中 1 种车型：                       │
│                                          │
│   ┌──────  确认用车  ──────┐             │
└──────────────────────────────────────────┘
```

关键视觉特征只有一个 —— **左右两个真挖出去的半圆缺口**。下面所有讨论都围绕这一点展开。

---

## 二、第一版：用 Circle 覆盖底色"挖洞"

最直觉的做法：撕线那一行做成 `Stack`，中间一条虚线、左右各放一个 **填外层底色** 的 `Circle`，看起来就像"缺口"。

```ts
Stack({ alignContent: Alignment.Center }) {
  // 中间水平虚线
  Line()
    .height(1)
    .startPoint([0, 0])
    .endPoint([1000, 0])
    .stroke('#1A000000')
    .strokeWidth(1)
    .strokeDashArray([4, 4])
    .width('100%')
    .margin({ left: 12, right: 12 })

  // 左右两个跟底色一致的"假缺口"
  Row() {
    Circle({ width: 16, height: 16 })
      .fill('#F5F6FA')
      .offset({ x: -8 })

    Blank()

    Circle({ width: 16, height: 16 })
      .fill('#F5F6FA')
      .offset({ x: 8 })
  }
  .width('100%')
}
.width('100%')
.height(16)
```

预览器里一截图，立刻发现两个问题：

**问题 1**：把卡片塞进 AI 聊天气泡里，气泡背景是浅蓝渐变，跟 `#F5F6FA` 不一致。缺口处直接露出 **浅灰色块**，看着像"贴上去的"。

**问题 2**：外层 `.shadow(...)` 加在最外面的 Column 上，阴影边界还是矩形圆角。**缺口边缘没有阴影包络**，视觉上根本没有"凹"感。

根本原因：这两个 Circle 不是真的"挖"出去，只是用同色色块 **盖** 出来的视觉错觉。一旦底色变、父容器有渐变、要截图分享、阴影需要沿轮廓走 —— 立刻穿帮。

---

## 三、第二版尝试：Path 组件 + 双层 Stack 补阴影

既然要"真挖洞"，自然想到用 SVG 路径描述一个 **带缺口的形状**，把卡片裁剪成这个形状。

我先画了一个带缺口的 Path（按 W=328, H=470, 缺口中线 y=144, 缺口半径 8）：

```text
M 16 0                    左上圆角起点
H 312                     上边线
A 16 16 0 0 1 328 16      右上圆角（顺时针）
V 136                     右边到缺口上沿
A 8 8 0 0 0 320 144       ↘ 右缺口上半（sweep=0 内凹）
A 8 8 0 0 0 328 152       ↗ 右缺口下半
V 454                     右边继续
A 16 16 0 0 1 312 470     右下圆角
H 16                      下边
A 16 16 0 0 1 0 454       左下圆角
V 152                     左边到缺口下沿
A 8 8 0 0 0 8 144         左缺口下半
A 8 8 0 0 0 0 136         左缺口上半
V 16                      左边继续
A 16 16 0 0 1 16 0        左上圆角
Z
```

然后我以为：直接拿 `Path()` 当裁剪形状传给 `.clipShape(...)` 就行了。但 IDE 立刻报红 —— `clipShape` 不接受绘制组件 `Path`。

继续凭直觉猜：那就 **双层 Stack**，底层一个 `Path` 加 `.shadow(...)` 出阴影，上层一个 Column 裁成相同形状，这样：

- 阴影 = 底层 Path 投影
- 内容 = 上层 Column 真裁剪

写完发现这个方向也是错的：

1. `new Path({ commands })` 这种写法在新版本 ArkUI 里不推荐，提示用 `PathShape`
2. 即使勉强跑起来，底层 Path 的阴影只在矩形外缘附近，**缺口处还是糊的**
3. 双层 Stack 要保证宽高严格一致，一旦内容尺寸变化两层就错位

显然方向错了。问题不出在"双层结构"，出在我对 ArkUI 渲染管线的假设是错的。

---

## 四、对照团队成熟做法，4 个非显然真相

公司项目里已经有一张样式几乎一样的"确认行程卡"，我把它的核心实现抠出来对照，发现 4 件事是我一开始凭经验 **猜错** 的。

### 真相 1：clipShape 入参用 PathShape，不是 Path

| 类 | 是什么 | 用在哪 |
|---|---|---|
| `Path` | **绘制组件**（视图节点） | 放在视图树里画线 / 形状 |
| `PathShape` | **Shape 对象** | 作为 `.clipShape(...)` / `.mask(...)` 的入参 |

两个名字几乎一样，文档分散在"绘制组件"和"通用属性 → 形状裁剪"两个章节，第一次写很容易混。

正确写法：

```ts
import { PathShape } from '@kit.ArkUI'

Column() { /* 内容 */ }
  .clipShape(new PathShape({ commands: this.getCardPath() }))
```

同套还有 `CircleShape`、`RectShape`、`EllipseShape`，遇到圆形 / 矩形裁剪也是用 `XxxShape`。

### 真相 2：shadow 自动沿 clipShape 后的轮廓外发光

我之前想当然 —— "clip 会把 shadow 一起裁掉，所以要双层"。

这是 Web / RN / SwiftUI 的经验。**在 ArkUI 里反过来**：

```ts
Column() { /* 内容 */ }
  .clipShape(new PathShape({ commands: '...' }))     // ① 先裁
  .shadow({ radius: 14, color: '#22000000', offsetX: 0, offsetY: 6 })  // ② 后影
```

ArkUI 的 `.shadow` 是渲染管线合成阶段加的 outer shadow，**它读的是 clipShape 算出的真实轮廓**。所以单层就够，阴影会自动沿凹陷弧线外发光，缺口的"凹"感被阴影衬出来。

**顺序敏感**：`.clipShape(...)` 必须在 `.shadow(...)` **前面** 调，否则 shadow 拿的是裁剪前的矩形轮廓。

### 真相 3：Path commands 单位是 px，UI 默认 vp

这条踩得最莫名其妙 —— 同样的代码在我自己的设备上看着对，换一个 DPI 不一样的设备，缺口就偏离了抬头底边。

查了一下：

- `onAreaChange` 回调里 `n.width / n.height` **单位是 vp**
- Path commands 字符串里的数字 **单位是 px**

ArkUI 同时有两套单位（vp = 逻辑像素，px = 物理像素），布局 / 属性走 vp，绘制层走 px。所有进 path 的尺寸都要 `vp2px(...)` 转换：

```ts
const r = vp2px(this.cornerRadius)    // 16vp → px
const nr = vp2px(this.notchRadius)    // 9vp → px
```

### 真相 4：撕线可以是"零体积 + top dashed border"

我一开始用 `Line` + `margin({ left: 12, right: 12 })` 手动给撕线两端留空，让它别撞到缺口。其实有更优雅的写法：

```ts
Row()
  .width('100%')
  .height(0)
  .border({
    width: { top: 1 },
    color: '#1A000000',
    style: BorderStyle.Dashed
  })
```

高度为 0 + 1px top dashed border = **零体积节点**。它会被外层的 `clipShape` 自动裁到缺口之间 —— 不用手动算 margin，缺口宽度怎么改它都自适应。

---

## 五、两个工程兜底必须写

光知道 4 个 API 还不够。不同卡片高度、不同首帧时序下，会冒出两类异常。

### 兜底 1：首帧 0 尺寸 → 卡片消失

`onAreaChange` 是布局完成后才回调的。卡片第一次绘制时 `cardWidth / cardHeight` 还是 0，如果 `getCardPath()` 直接用 0 算路径，会算出 0 大小的形状 —— **整张卡片瞬间消失，下一帧才显出来**，肉眼能感到一闪。

兜底：首帧返回一个超大矩形，**等效于不裁剪**。

```ts
if (w <= 0 || h <= 0) {
  return 'M0 0 L2000 0 L2000 2000 L0 2000 Z'
}
```

### 兜底 2：卡片太矮 → 路径自交

如果卡片高度小于 `2 * (圆角半径 + 缺口半径)`，缺口的上下竖边长度会变成负数，path 自交，渲染异常。

兜底：太矮就退化成 **无缺口圆角矩形**，反正这种尺寸下缺口也没意义。

```ts
const minNy = r + nr
const maxNy = h - r - nr
if (maxNy <= minNy) {
  return /* 无缺口圆角矩形路径 */
}
```

还要钳制缺口中线 `ny`，必须落在 `[minNy, maxNy]` 之间，否则上下竖边会反向：

```ts
let ny = this.notchY > nr ? this.notchY : h / 2
if (ny < minNy) ny = minNy
if (ny > maxNy) ny = maxNy
```

---

## 六、缺口位置不要写死，让它"贴着抬头底边走"

如果把缺口 y 坐标写死，抬头里多一行文字 / 换语言 / 字号变化，缺口都会错位。

正确做法是给抬头区也加一个 `onAreaChange`，测出抬头实际高度：

```ts
@Local headerH: number = 0   // 抬头高，vp，给背景层定高
@Local notchY: number = 0    // 缺口中线 y，px，给路径用

// TicketHeader 最外层 Column
.onAreaChange((_o: Area, n: Area) => {
  this.headerH = Number(n.height)
  this.notchY = vp2px(Number(n.height))   // 缺口中线 = 抬头底边
})
```

抬头改任何内容，缺口都跟着走。

---

## 七、完整实现

把上面所有点拼起来，最终代码长这样。

### 7.1 字段 + 常量

```ts
import { TripCard } from '../models/chatModel'
import { PathShape } from '@kit.ArkUI'

@ComponentV2
export struct ConfirmTripCardComp {
  @Param @Require card: TripCard

  @Local cardWidth: number = 0     // px
  @Local cardHeight: number = 0    // px
  @Local notchY: number = 0        // 缺口中心 y，px
  @Local headerH: number = 0       // 抬头高，vp

  private readonly cornerRadius: number = 16
  private readonly notchRadius: number = 9
}
```

### 7.2 路径生成函数

```ts
getCardPath(): string {
  const w = this.cardWidth
  const h = this.cardHeight

  // 兜底 1：首帧 0 尺寸 → 返回大矩形 = 等效不裁剪
  if (w <= 0 || h <= 0) {
    return 'M0 0 L2000 0 L2000 2000 L0 2000 Z'
  }

  const r = vp2px(this.cornerRadius)
  const nr = vp2px(this.notchRadius)
  const minNy = r + nr
  const maxNy = h - r - nr

  // 兜底 2：太矮放不下缺口 → 退化为无缺口圆角矩形
  if (maxNy <= minNy) {
    return `M ${r} 0 H ${w - r} A ${r} ${r} 0 0 1 ${w} ${r}`
      + ` V ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h}`
      + ` H ${r} A ${r} ${r} 0 0 1 0 ${h - r}`
      + ` V ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
  }

  // 钳制缺口中线
  let ny = this.notchY > nr ? this.notchY : h / 2
  if (ny < minNy) ny = minNy
  if (ny > maxNy) ny = maxNy

  // 4 圆角 + 两侧半圆缺口（sweep=0 内凹）
  return `M ${r} 0`
    + ` H ${w - r} A ${r} ${r} 0 0 1 ${w} ${r}`
    + ` V ${ny - nr} A ${nr} ${nr} 0 0 0 ${w} ${ny + nr}`
    + ` V ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h}`
    + ` H ${r} A ${r} ${r} 0 0 1 0 ${h - r}`
    + ` V ${ny + nr} A ${nr} ${nr} 0 0 0 0 ${ny - nr}`
    + ` V ${r} A ${r} ${r} 0 0 1 ${r} 0 Z`
}
```

### 7.3 外层结构（4 个关键属性）

```ts
build() {
  Stack({ alignContent: Alignment.TopStart }) {
    Column() {
      // 抬头区
      this.TicketHeader()

      // 撕线：高 0 + dashed top border
      Row()
        .width('100%')
        .height(0)
        .border({
          width: { top: 1 },
          color: '#1A000000',
          style: BorderStyle.Dashed
        })

      // 白色区：地图 / 价格 / 按钮
      Column() { /* ... */ }
    }
    .width('100%')
    .backgroundColor(Color.White)
    // ① 先裁形状
    .clipShape(new PathShape({ commands: this.getCardPath() }))
    // ② 后加阴影 → 沿凹陷外发光
    .shadow({
      radius: 14,
      color: '#22000000',
      offsetX: 0,
      offsetY: 6
    })
    // ③ 测真实尺寸 → 触发路径重算
    .onAreaChange((_o: Area, n: Area) => {
      this.cardWidth = vp2px(Number(n.width))
      this.cardHeight = vp2px(Number(n.height))
    })
  }
  .width('100%')
}
```

### 7.4 抬头：渐变 + 缺口位置回填

```ts
@Builder
TicketHeader() {
  Stack() {
    // 背景层：蓝底 + 横向白→透渐变
    Column()
      .width('100%')
      .height(this.headerH)
      .backgroundColor('#FF00B5D9')
      .linearGradient({
        angle: 90,
        colors: [['#FFFFFFFF', 0.0], ['#00FFFFFF', 1.0]]
      })

    // 内容层 + 纵向半透白→白渐变
    Column({ space: 20 }) {
      // 标题 + 黄色高亮
      Stack({ alignContent: Alignment.BottomStart }) {
        Row().width(84).height(8).backgroundColor('#FFD91A').borderRadius(4)
        Text('确认行程')
          .fontSize(20).lineHeight(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E6000000')
      }

      // 起终点三行
      Column() { /* 省略具体行 */ }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 20 })
    .linearGradient({
      angle: 180,
      colors: [['#B3FFFFFF', 0.0], ['#FFFFFFFF', 1.0]]
    })
    // ④ 缺口位置 = 抬头底边
    .onAreaChange((_o: Area, n: Area) => {
      this.headerH = Number(n.height)
      this.notchY = vp2px(Number(n.height))
    })
  }
  .width('100%')
}
```

---

## 八、一个图理解整条数据流

```text
父布局给宽高
    ↓
[Column] onAreaChange 回调
    ↓
cardWidth / cardHeight (px) 更新
                                      ┐
[TicketHeader] onAreaChange 回调       │  @Local 字段变化
    ↓                                  │  → ArkUI 触发重渲
headerH (vp) / notchY (px) 更新        ┘
    ↓
build() 重新执行
    ↓
getCardPath() 用最新尺寸生成 commands
    ↓
new PathShape({ commands }) 给 clipShape
    ↓
渲染管线：
  1. 按 PathShape 裁剪内容
  2. 沿裁剪后的真实轮廓画 shadow
  3. 撕线（零体积节点）自动被裁到缺口之间
```

整条链路里没有一个写死的尺寸。卡片宽度由父布局决定、缺口位置由抬头决定、撕线长度由 clipShape 决定 —— 整体响应式。

---

## 九、一句话记忆法

```text
ClipShape 用 PathShape，
Shadow 同层跟 Clip 走，
Path 用 px，UI 用 vp，
首帧太矮要兜底，
撕线高 0 加 dashed border，
缺口贴着抬头底边走。
```

---

## 十、回头看第一版错在哪

回过头看第一版"Circle 覆盖底色"的做法，错的不是"没用对 API"，而是 **思路本身**：

- "假缺口"思路 → 缺口只是视觉错觉，没法承载阴影、没法适应不同底色、不可截图分享
- "真挖洞"思路 → 缺口是物理事实，shadow / 撕线 / 子节点都自然受其影响

ArkUI 提供 `clipShape + PathShape` 是为了让 **形状本身变成布局的一部分**。一旦想清楚这件事，所有 API 都顺理成章：

- 为什么是 `PathShape` 而不是 `Path`？因为它是参与"形状计算"的，不参与视图树
- 为什么 shadow 自动沿凹陷走？因为合成阶段已经知道真实轮廓
- 为什么撕线零体积就够？因为 clipShape 会替我们裁
- 为什么要 `onAreaChange` + `vp2px`？因为形状参数走绘制层

---

## 十一、参考

- [ArkUI 总入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkui)
- [ArkUI 阴影 shadow](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-shadow-effect)
- 形状裁剪 / Path / PathShape：在 ArkUI 文档站搜 "形状裁剪"、"Path"、"PathShape" 定位
- [SVG Path 命令规范（MDN）](https://developer.mozilla.org/zh-CN/docs/Web/SVG/Tutorial/Paths) —— M / L / H / V / A / Z 与 sweep-flag 的含义跟 commands 字符串完全一致
