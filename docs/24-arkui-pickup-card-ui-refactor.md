# 打车票根卡片 UI 重构：从 Circle 挖洞到 clipShape PathShape，再到 100% 自适应

> 项目：`MyApplication`（AI 助手 demo）
> 目标文件：`chat/src/main/ets/components/PickupConfirmCardComp.ets`
> 主题：把"确认上车点"卡片从早期的 **Circle.offset + clip 挖洞** 方案换成 **clipShape PathShape 一次性绘出整张票根轮廓**，再把所有写死的宽高拿掉，让卡片在不同消息容器宽度下都能渲染。这一篇是 [21-arkui-ticket-card-clipshape-pathshape](./21-arkui-ticket-card-clipshape-pathshape.md) 的实战续篇 —— 把"路由行的 `?` 圆点、虚线、定位图标"、"进站口按钮 + list 菜单"、"自适应布局"三块组件级细节讲清楚。

---

## 一、卡片到底长什么样

```text
┌──────────────────────────────┐
│  确认上车点                  │  ← 标题 + 黄色高亮 + 蓝色渐变抬头
│  ──                          │
│  ? --- 您在哪里上车？        │  ← 路由行：? 圆点 + 虚线 + 📍 + 双行文字
│  |     香港中国企业协会      │
│  📍                          │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤  ← 撕线 + 左右半圆缺口（票根的"撕开线"）
│                              │
│  ① 香港西九龙站  65.9km      │
│     香港特别行政区...        │
│  [   进站口1   ]  [≡]        │  ← Text chip + list 图标按钮
│  ── 分隔线 ──                │
│  ② 高铁西九龙站(K出口)       │
│     香港特别行政区...        │
│  ── 分隔线 ──                │
│  ③ 高铁西九龙站(K出口)       │
│                              │
│  [    查看更多    ]          │  ← 浅蓝底蓝字按钮
└──────────────────────────────┘
```

上半部分是 **抬头**（渐变蓝 + 黄高亮 + 路由行），下半部分是 **白色 POI 区**（3 个上车点 + 分隔线 + 查看更多），中间靠 **撕线 + 左右半圆缺口** 形成票根感。

---

## 二、为什么从 Circle.offset 换到 clipShape PathShape

### 2.1 旧方案的"撕线"是这么做的

```ts
// 旧版（commit 之前）
Stack({ alignContent: Alignment.Center }) {
  Line().strokeDashArray([4, 4]).width('100%')      // 中间水平虚线

  Row() {
    Circle({ width: 14, height: 14 })
      .fill(this.theme.bg)
      .offset({ x: -7, y: 0 })                       // 左圆心移到卡片左边缘

    Blank()

    Circle({ width: 14, height: 14 })
      .fill(this.theme.bg)
      .offset({ x: 7, y: 0 })                        // 右圆心移到卡片右边缘
  }
}
```

外层 Column 给 `.clip(true)`，落在外面的半圆被裁掉，**形成左右两个半圆挖洞**。

**这套方案能跑，但有 3 个问题**：

| 问题 | 表现 |
|---|---|
| ① 圆色绑定外层主题 | 圆 `.fill(theme.bg)` 跟卡片所在背景同色。一旦卡片被嵌进**别的颜色容器**（比如 ChatListComp 里背景被换了），圆就成了"挖不掉"的色块 |
| ② shadow 顺着方形外框 | 整张卡片是方形，shadow 是方形 shadow。**缺口处没有阴影**，"撕开"的视觉不立体 |
| ③ 写死的 `Stack + Row + Circle` | 圆心位置靠 `.offset(-7, 0)` 推到边缘。一旦缺口位置要跟着抬头高度变（不同字数会让抬头高度不同），调整成本高 |

### 2.2 新方案：clipShape 一刀切出"整张票根轮廓"

`clipShape(PathShape)` 把整张卡片的轮廓（4 个圆角 + 左右两个半圆缺口）作为一条 SVG path 命令喂给 ArkUI，**整张卡的可见区域 = 这条 path 内部**：

```ts
.clipShape(new PathShape({ commands: this.getCardPath() }))
```

`getCardPath()` 返回的命令：

```text
M r 0                                      ← 从左上圆角终点开始
H w-r  A r r 0 0 1 w r                     ← 上边 + 右上圆角
V ny-nr A nr nr 0 0 0 w ny+nr              ← 右边到缺口上沿 + 右半圆向内挖
V h-r  A r r 0 0 1 w-r h                   ← 右边继续 + 右下圆角
H r    A r r 0 0 1 0 h-r                   ← 下边 + 左下圆角
V ny+nr A nr nr 0 0 0 0 ny-nr              ← 左边到缺口下沿 + 左半圆向内挖
V r    A r r 0 0 1 r 0 Z                   ← 左边收尾 + 左上圆角
```

带来 3 个改变：

| 维度 | 旧 | 新 |
|---|---|---|
| **缺口的"色"** | 圆 fill 主题色硬贴上去 | path 真的把那块**镂空**，背景透出来，永远跟得上外层颜色 |
| **shadow** | 方形外框 | 沿着 path 描边，**缺口处真的有阴影"凹"进去** |
| **缺口位置** | 写死在中间 | `notchY` 来自抬头 `onAreaChange` —— 不管抬头多高，缺口永远卡在抬头和白色区的交界处 |

> path 实现细节参见 [21-arkui-ticket-card-clipshape-pathshape](./21-arkui-ticket-card-clipshape-pathshape.md)，这里不再展开。本篇之后聚焦"路由行 + 进站口按钮 + 自适应"三块组件级细节。

---

## 三、路由行：`?` 圆点 / 虚线 / 📍 的三段式

抬头里"您在哪里上车？/ 香港中国企业协会"这一行，左侧是个 **12vp 宽的小柱**：上面一个黑色圆里的白色 `?`，中间一段虚线，下面一个 📍 图标。看起来普通，里面有几个值得记一下的小技巧。

### 3.1 黑色圆里的白色 `?` —— 不用 Stack，直接 Text 当圆

第一反应一定是这么写：

```ts
Stack() {
  Circle({ width: 12, height: 12 }).fill('#E6000000')
  Text('?').fontSize(8).fontColor('#FFFFFF')
}
```

能跑，但**多了一层 Stack**。其实更短的写法是让 **Text 本身就是圆**：

```ts
Text('?')
  .fontSize(8)
  .fontColor('#FFFFFF')
  .textAlign(TextAlign.Center)      // 横向居中
  .width(12)
  .height(12)
  .lineHeight(12)                   // 等于 height → 纵向几何居中
  .backgroundColor('#E6000000')     // Text 自带 background → 黑底
  .borderRadius(256)                // 超大半径 → 强制变圆
  .margin({ top: 2 })
```

关键三件套：

| 属性 | 作用 |
|---|---|
| `textAlign(Center)` | 文字横向居中 |
| `lineHeight(12)` 跟 `height(12)` 一致 | 文字纵向几何居中（baseline 不在中点，但行高强行居中显示） |
| `borderRadius(256)` | 任何 >= width/2 的值都能强制圆，写 256 是社区习惯 |

**为什么 fontSize 选 8 而不是 10**：12vp 的圆里，问号字形高度需要 < ~10vp 才不会顶到边。`fontSize(8)` + `lineHeight(12)` 让问号上下各有 ~2vp 留白，视觉上更像"圆点里的字符"而不是"塞满圆的字符"。

> 这种"Text 当圆"写法的本质：Text 是 CommonMethod，自带 background / borderRadius / padding。但凡需要"一个圆 + 中间一个字符"，都可以省掉 Stack。

### 3.2 虚线段

```ts
Line()
  .width(1)
  .height(12)
  .startPoint([0, 0])
  .endPoint([0, 12])
  .stroke('#B5BAC4')
  .strokeWidth(1)
  .strokeDashArray([2, 2])         // 实线 2vp + 空 2vp 交替
```

`strokeDashArray([2, 2])` 是核心，控制 dash 的"实 / 空"长度。改成 `[4, 2]` 就是长实线短空，按视觉调整。

### 3.3 📍 图标

```ts
Image($r('app.media.location'))
  .width(12)
  .height(12)
  .objectFit(ImageFit.Contain)
  .draggable(false)                // 防止长按触发系统拖拽
  .margin({ top: 2 })              // 跟虚线之间留 2vp gap
```

`draggable(false)` 是踩过坑的：Image 默认 draggable 为 true，长按会触发系统拖拽预览（半透明阴影 + 飘起来），用户以为卡死了。**所有非用户主动拖的 Image 都加这一条**。

### 3.4 三段式组合

```ts
Column() {
  Text('?') ...               // 圆点 12×12
  Line() ...                  // 虚线 1×12
  Image(location) ...         // 📍 12×12
}
.width(12)
.alignItems(HorizontalAlign.Center)
```

整列宽度写死 12 + 横向居中，每个子元素都 12 宽，**视觉上就是一根 12vp 的细柱**。

---

## 四、进站口按钮 + list 菜单：layoutWeight(1) + Image 包 Column 居中

第一个 POI（香港西九龙站）下面有一行：

```text
[      进站口1      ]   [ ≡ ]
```

左边是个带框的 chip，右边是个带框的 list 菜单按钮（公司项目里通常点击展开切换进站口）。

### 4.1 第一版写法 —— 三横线模拟菜单

最早右边那个 list 按钮我直接用 3 个细长 Row 画了 ≡：

```ts
Column({ space: 3 }) {
  Row().width(14).height(2).backgroundColor('#99000000').borderRadius(1)
  Row().width(14).height(2).backgroundColor('#99000000').borderRadius(1)
  Row().width(14).height(2).backgroundColor('#99000000').borderRadius(1)
}
.padding(7)
.border({ width: 1, color: '#1A000000', radius: 8 })
```

能跑、不依赖外部资源，但**真要还原设计稿** —— 设计稿里那个 list 图标是带细节的（每根横线左边一个小圆点）—— 三个 Row 是糊不出来的。

### 4.2 第二版：Image + Column 容器

设计组给了 `list.png`，丢到 `chat/src/main/resources/base/media/list.png`，写法变成：

```ts
Column() {
  Image($r('app.media.list'))
    .width(14)
    .height(14)
    .objectFit(ImageFit.Contain)
    .draggable(false)
}
.padding(7)
.border({ width: 1, color: '#1A000000', radius: 8 })
.justifyContent(FlexAlign.Center)
.alignItems(HorizontalAlign.Center)
```

**为什么外层套个 Column 而不是直接给 Image 加 padding + border**：

- Image 直接 `.padding(7)` 时，padding 会**进入图片的可绘制区域**，让 `objectFit(Contain)` 重新计算 → 图片实际渲染尺寸不再是 14×14
- 套一个 Column，把"内边距 + 边框"剥离给容器，Image 始终是 14×14，可控

这个细节是踩过一次坑才意识到的 —— 在公共组件里给 Image 加 padding 是个错误模式，**容器管布局，图片管绘制**。

### 4.3 左边 chip：layoutWeight(1) 让进站口自动撑开

```ts
Row() {
  Text('进站口1')
    .layoutWeight(1)                   // ← 关键：吃掉除 list 按钮外的所有宽度
    .maxLines(1)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .textAlign(TextAlign.Center)       // chip 内文字居中（被层级压缩时也好看）
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .border({ width: 1, color: '#1A000000', radius: 8 })

  Column() { Image($r('app.media.list')) ... }       // list 按钮，自然宽度 30vp 左右
    .margin({ left: 4 })
}
.width('100%')
.alignItems(VerticalAlign.Bottom)
```

`layoutWeight(1)` 是 Flex 子项的"弹性占比"。在 Row 里 = "占满剩余宽度"。**绝对不要写死 `.width(264)`**，因为：

- 父容器宽度变了（不同消息气泡宽度不同）→ 264 就溢出或留白
- 进站口文字变了（"进站口1" → "进站口10号航站楼"）→ 264 不够装

`layoutWeight(1)` 才是"自适应布局"的正确写法。

---

## 五、自适应 vs 写死：踩过的坑

中间有一版我为了"完美还原 UI 稿"，把 Stack + 票根 Column 的宽高全写死：

```ts
.width(328).height(414)        // Stack
.width(328).height(400)        // 票根 Column
.width(264)                    // 进站口 Text
```

**结果下面 POI 直接被裁了一节**。原因：

```text
Stack(414)
  └─ Column(286)   ← 我写的高度
      ├─ Header(114)              ← 抬头实际高度
      ├─ TearLine(0)              ← 撕线
      └─ WhiteArea(剩 286-114=172)  ← 内容自然撑开需要 305，被 clipShape 裁掉 ~133
```

设计稿上"白色区 286"是**白色区**的高度，不是整张票根 Column 的高度。整张 Column = 抬头 114 + 撕线 0 + 白色 286 = **400**。

### 这次的结论：先 100% 渲染，再调对齐

最终方案是把所有写死宽高拿掉：

```ts
// Stack
.width('100%')
.constraintSize({ maxWidth: '92%' })   // 只锁最大不锁绝对值

// 票根 Column
.width('100%')                          // 没有 .height

// 进站口 Text
.layoutWeight(1)                        // 没有 .width
```

- 高度让内容自然撑开 → 抬头 + 撕线 + 白色区，加起来多大就多大
- 宽度跟父容器走，封顶 92%（防止贴满气泡边）
- 缺口 `notchY` 通过 `onAreaChange` 实时拿抬头高度算出来，跟谁的 layout 都解耦

**心智模型**：UI 复刻时的优先级是 **能渲染 > 像 > 一模一样**。先保证三层结构都渲染出来，再回头量尺寸调像素。先写死，clipShape 一裁，问题全藏在裁掉的部分里反而看不见。

---

## 六、阴影顺序敏感 —— `clipShape` 放在 `shadow` 之前还是之后？

这个坑我之前在 21 也提过，再强调一次：

```ts
Column() { ... }
  .clipShape(...)        // ① 先裁形状
  .shadow({ ... })       // ② 沿裁完的形状描阴影
```

**顺序反了**：

```ts
.shadow({ ... })       // ① 先沿方形外框出阴影
.clipShape(...)        // ② 再裁形状 → 阴影也被裁掉了！
```

不仅缺口处没阴影，整张卡的阴影全部消失。**`clipShape` 永远在 `shadow` 之前**。

---

## 七、`@Builder` 拆分时的响应式坑

整个组件用了 5 个 `@Builder` 拆模块化：

```ts
@Builder TicketHeader()       // 抬头
@Builder RouteRow()           // 抬头里的路由行
@Builder IndexBadge(num)      // POI 序号圆点
@Builder Divider()            // 分隔线
@Builder LocationItemFull()   // 第 1 个完整 POI
@Builder LocationItemSimple() // 第 2/3 个简化 POI
@Builder MoreButton()         // 查看更多
```

**响应式字段必须在 `@ComponentV2.build` 顶层访问，不能透过 `@Builder` 参数传**：

```ts
// ❌ 错：响应式字段透过参数传给 @Builder，参数里的依赖丢失，UI 不刷新
@Builder
HeaderWithTitle(title: string) {       // title 来自 @Local
  Text(title)
}
build() {
  this.HeaderWithTitle(this.title)
}

// ✅ 对：@Builder 内部直接读 this.xxx
@Builder
TicketHeader() {
  Text(this.title)                     // 直接 this 读，依赖被 @ComponentV2 收集
}
```

我这次封装时所有响应式字段（`headerH` / `notchY`）都是 `@Builder` 内 `this.xxx` 直读，没有当参数传，所以 layout 变化能正常触发 `getCardPath()` 重算。

---

## 八、一句话心智模型

```text
旧票根 = Circle.offset + clip → 撕线靠贴色块、shadow 跟着方形
新票根 = clipShape(PathShape) → 整张轮廓一刀切出来，缺口真的镂空，shadow 沿 path

? 圆点 = Text + textAlign + lineHeight + borderRadius(256)，省一层 Stack
list 按钮 = Image 包 Column 居中，padding 给容器不给图

自适应 > 写死，先 100% 渲染再量像素
clipShape 永远在 shadow 之前
```

---

## 九、顺口溜

```text
PathShape 一刀切，圆角缺口一次成；
Text 当圆别 Stack，居中三件 lineHeight 平。

Image 别加 padding，外面套层 Column 守；
进站口走 layoutWeight，写死高度坑下游。

shadow 别走在裁前，撕线缺口才有影；
@Builder 参数不响应，this 直读才会刷。
```

---

## 十、参考

- [PathShape API（@kit.ArkUI）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-arkui-shape)
- [Image 组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-image)
- [Text 组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-text)
- [@Builder 装饰器](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-builder)
- 本系列前作：[21-arkui-ticket-card-clipshape-pathshape](./21-arkui-ticket-card-clipshape-pathshape.md)
