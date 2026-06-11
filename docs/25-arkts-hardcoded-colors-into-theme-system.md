# 49 处硬编码颜色接入主题系统：为什么没用 $r('app.color')，以及批量替换的坑

> 项目：`MyApplication`（AI 助手 demo）
> 涉及：`common/.../ThemeState.ets`、两张票根卡、`ChatInputComp`
> 主题：上一篇我给 `ThemeState` 接上了系统（`onConfigurationUpdate` 同步 `isDark`），理论上手机切暗色 App 就该跟着变。但实测票根卡**纹丝不动**——因为它的颜色全是 `'#FF00B5D9'` 这种硬编码字符串，根本没经过 `ThemeState`。这篇就是把这 49 处硬编码批量接入主题系统的实战，记录一个架构决策和几个真实踩到的坑。

---

## 一、引子：开关接好了，但灯没接线

上一篇（24）的修复让 `ThemeState.isDark` 能跟随系统切换。但 `ThemeState` 只是个"开关"——只有**用了 `this.theme.xxx` 的地方**才会被它驱动。

我的票根卡颜色长这样：

```ts
.fontColor('#E6000000')           // 硬编码
.backgroundColor('#FF00B5D9')     // 硬编码
.linearGradient({ colors: [['#FFFFFFFF', 0.0], ['#00FFFFFF', 1.0]] })  // 硬编码
```

**全是写死的字符串**，跟 `ThemeState` 没有半点关系。所以开关再灵，这些灯也不亮——它们压根没接线。

这篇就是给它们接线。扫出来一共 **49 处**：票根卡 47 处 + 输入框 2 处。

---

## 二、第一个决策：`$r('app.color')` 还是接入 ThemeState？

接线有两条路，我差点选错。

**路 A（鸿蒙原生）**：把颜色配进 `resources/base/element/color.json` + `resources/dark/element/color.json`，代码用 `$r('app.color.xxx')`，系统自动切。

**路 B（接入现有 ThemeState）**：硬编码换成 `this.theme.xxx`，复用上一篇已接系统的主题。

直觉是路 A 更"正统"。但动手前我扫了一眼，发现路 A 有个**硬阻断**：

```ts
.linearGradient({
  angle: 90,
  colors: [['#FFFFFFFF', 0.0], ['#00FFFFFF', 1.0]]  // 这里塞 $r 很容易踩坑
})
```

`$r('app.color.xxx')` 返回的是 `Resource` 类型，而 `linearGradient` 的 colors 对 Resource 颜色支持不稳。我票根卡有 **4 处渐变**，全是抬头的核心视觉。这些要是不能用 `$r`，就得保留硬编码 → 变成"一部分 `$r`、一部分硬编码"的割裂状态。

而且我**已经有 ThemeState**（亮暗两套值都写好了，上篇还接了系统）。走路 A 等于把这些值重做一遍搬进 json，还得两套并存。

对比一下：

| | 路 B：接入 ThemeState | 路 A：$r('app.color') |
|---|---|---|
| 返回类型 | `string` | `Resource` |
| linearGradient | ✅ 接受 | ⚠️ 支持不稳 |
| 复用已有主题 | ✅ 直接用 | ❌ 重做一遍 |
| 方案数 | 一套 | 两套并存 |

**结论**：选路 B。`this.theme.xxx` 返回 string，渐变 / 裁剪 / 阴影 / 描边全部接受，一套方案搞定。

> 教训：选技术方案前先扫一眼"有没有用不了的地方"。`linearGradient` 这个阻断点，是决定整个方案走向的关键，幸好动手前发现了。

---

## 三、设计原则：亮色值 = 原值，零视觉变化

给 `ThemeState` 加票根专属色块时，我定了一条铁律：

```text
亮色值 = 组件里原本的硬编码值（一字不改）
暗色值 = 深色推导（新增）
```

这样**亮色下视觉零变化**——替换前后亮色完全一样，只是把字符串抽成了 getter。暗色才是新增的分支。这条原则让我替换得很安心，不用担心改坏亮色。

示例：

```ts
/** 主文字（90%） */
get ticketTextHeavy(): string {
  return this.isDark ? '#E6FFFFFF' : '#E6000000'   // 亮色 = 原硬编码值
}

/** 卡片底色（暗色转深灰） */
get ticketSurface(): string {
  return this.isDark ? '#2C2C2E' : '#FFFFFF'
}

/** 品牌蓝：抬头底 / 按钮 / 序号圆（亮暗一致） */
get ticketBrand(): string {
  return '#FF00B5D9'   // 品牌色亮暗都一样，不分支
}
```

颜色推导规律：
- 文字：`#E6000000`（90% 黑）→ `#E6FFFFFF`（90% 白），透明度不变，黑白翻转
- 卡底：`#FFFFFF` → `#2C2C2E`（深灰）
- 品牌色 / 高亮黄：亮暗一致，不分支

---

## 四、一个去重技巧：语义不同但值相同的颜色

票根卡有两个渐变：

```ts
// 横向渐变：白(不透明) → 白(透明)
colors: [['#FFFFFFFF', 0.0], ['#00FFFFFF', 1.0]]

// 纵向渐变：白(70%) → 白(不透明)
colors: [['#B3FFFFFF', 0.0], ['#FFFFFFFF', 1.0]]
```

注意 `#FFFFFFFF` 出现了**两次**，语义不同：横向是"起点"、纵向是"终点"。但它们都代表**"不透明的卡片底色"**，暗色下都该变成 `#FF2C2C2E`。

所以我没拆成两个 getter，而是**合并成一个**：

```ts
/** 渐变·不透明卡片色（横向起点 + 纵向终点，融入卡底） */
get ticketGradOpaque(): string {
  return this.isDark ? '#FF2C2C2E' : '#FFFFFFFF'
}
```

好处有两个：少一个 getter，更重要的是——**批量替换时 `#FFFFFFFF` 无歧义**，两处都该换成 `ticketGradOpaque`，一个 `replace_all` 直接搞定。

> 归一原则：颜色 getter 按**语义和值**归类，不按"出现在哪"。值相同的合并。

---

## 五、批量替换的两个坑

### 坑 1：`#FFFFFF`（6 位）会不会误伤 `#FFFFFFFF`（8 位）？

我用 `replace_all` 批量替换。但 `'#FFFFFF'`（白字）和 `'#FFFFFFFF'`（渐变不透明白）只差两个 F，`replace_all '#FFFFFF'` 会不会把 `'#FFFFFFFF'` 的前半截也换了？

**不会**——关键在 **old_string 带引号**：

```text
匹配 "'#FFFFFF'"   → 单引号 + #FFFFFF + 单引号
目标 "'#FFFFFFFF'" → 单引号 + #FFFFFFFF + 单引号
```

`'#FFFFFF'` 后面跟的是 `FF'`，不是 `'`——引号位置对不上，精确不匹配。所以替换颜色时 **old_string 一定要带引号**，把颜色当完整字符串字面量匹配，而不是裸 hex。

### 坑 2：`Color.White` 不在 hex 搜索里

我先 `grep '#[0-9A-Fa-f]{6}'` 扫硬编码，替换完以为干净了。结果卡片底色还是没接入——因为卡底用的是：

```ts
.backgroundColor(Color.White)   // 枚举，不是 '#FFFFFF'！
```

`Color.White` 是 ArkUI 的颜色枚举，**不带 `#`**，hex 正则根本搜不到它。我得单独 `grep Color.White` 再替换：

```ts
.backgroundColor(Color.White)  →  .backgroundColor(this.theme.ticketSurface)
```

> 教训：扫硬编码颜色，除了 `#hex`，别忘了 `Color.X` 枚举形式（`Color.White` / `Color.Black` / `Color.Red`…）。两种都要扫。

---

## 六、最大的风险：@Builder 响应式

票根卡的颜色大量在 `@Builder` 里访问：

```ts
@Builder
TicketHeader() {
  // ...
  Text('确认行程').fontColor(this.theme.ticketTextHeavy)   // @Builder 内访问 theme
}
```

而 `this.theme.ticketTextHeavy` 这个 getter 内部读 `this.theme.isDark`（`@Trace`）。问题来了：组件的 `build()` 顶层**没有**直接读 `isDark`，只有 `@Builder` 内读了。

我之前踩过 **@Builder 传参丢响应式**的坑——`@ComponentV2` 跨 `@Builder` 边界的依赖追踪有不确定性。这次虽然是"@Builder 内直接 this 访问"（不是传参，大概率没事），但仍是风险区。

**保险方案**：在 `build()` 最顶层"触碰"一次 `isDark`，强制建立组件级依赖：

```ts
build() {
  const followDark: boolean = this.theme.isDark   // 顶层触碰，确保切暗色时整卡重渲
  Stack({ alignContent: Alignment.TopStart }) {
    // ...
  }
}
```

我的做法是：先不加，跑起来重点验证"切暗色时 @Builder 部分颜色变不变"。如果不变，再加这一行。**不预防性加未使用变量，但知道风险在哪、修复是什么**。

---

## 七、通用色直接复用，不重复造

输入框 `ChatInputComp` 的 2 处硬编码，我没新增 getter——它们正好匹配 `ThemeState` **已有的通用色**：

```ts
.backgroundColor('#F5F5F5')  →  .backgroundColor(this.theme.inputBg)   // 输入框底
.backgroundColor('#FFFFFF')  →  .backgroundColor(this.theme.surface)   // 输入栏底
```

`inputBg` / `surface` 是 ThemeState 早就有的通用 getter。

> 原则：**通用 UI 用通用色**（`surface` / `inputBg` / `textPrimary`），**业务卡片才加专属色**（`ticketBrand` / `ticketTextHeavy`）。别给输入框也造一套 `inputXxx` 专属色，复用通用的就好。

---

## 八、一句话心智模型

```text
硬编码色接入主题：
  亮色值 = 原值（保证零视觉变化），暗色值 = 推导；
  值相同的颜色合并一个 getter；
  replace_all 时 old_string 带引号，防 6 位误伤 8 位；
  别忘了 Color.X 枚举也是硬编码；
  @Builder 内访问 theme 有响应式风险，顶层触碰 isDark 兜底；
  通用色复用，业务色专属。
```

---

## 九、顺口溜

```text
渐变接不了 Resource，主题方案选 string；
亮色照搬零变化，暗色推导新分支；
带引号防误伤，Color.White 别漏网；
@Builder 怕丢响应式，顶层 isDark 触一触。
```

---

## 十、参考

- [资源分类与访问](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/resource-categories-and-access)
- [深色模式适配](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-adaptation-dark-mode)
- 上一篇：资源与暗色模式 + onConfigurationUpdate 跟随系统（本仓库 24 篇）

---

## 十一、验证 & TODO

验证：

```text
1. 亮色下：两张票根卡 + 输入框，和改之前【视觉完全一致】（零变化验证）
2. 手机切暗色：抬头深灰渐变、文字转白、卡底深灰、输入框变暗
3. 【重点】切暗色那一刻，票根卡 @Builder 部分（抬头/列表）颜色是否跟着变
4. 若第 3 步不变 → build 顶层加 const followDark = this.theme.isDark
```

TODO：

- [ ] 验证 @Builder 响应式，必要时加顶层触碰
- [ ] TextInput 补 `.fontColor(this.theme.inputText)`，否则暗色下输入的字偏黑看不清
- [ ] 票根卡的定位图标（`$rawfile`）暗色下还是原图，考虑换成 `$r` 媒体资源 + dark 版
