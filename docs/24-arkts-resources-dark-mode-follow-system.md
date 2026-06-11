# ArkTS 资源与暗色模式：为什么我手机切暗色，App 内容区却不变

> 项目：`MyApplication`（AI 助手 demo）
> 涉及：`common/.../ThemeState.ets`（主题系统）、`entry/.../EntryAbility.ets`、`resources/` 目录
> 主题：入职第四周系统学资源体系时，我盯着自己的 demo 发现一个之前一直没注意的问题——手机切到暗色，状态栏变了，但我的卡片、页面颜色**纹丝不动**。一开始以为是哪里写错了，深挖之后才明白：这不是 bug，是我的主题方案天生不跟系统联动。本篇记录从 `$r`/`$rawfile` 基础，到限定符体系，再到定位并修复这个 gap 的全过程。

---

## 一、引子：一个我以为是 bug 的 gap

我的 demo 有一套自己的主题系统 `ThemeState`，支持亮 / 暗两套颜色。`EntryAbility` 里也设了跟随系统：

```ts
this.context.getApplicationContext()
  .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)  // 跟随系统
```

按理说，手机切暗色，App 应该整体变暗。但实测：

```text
手机设置 → 深色模式
   ↓
系统状态栏、系统级 UI：变暗 ✓
我的卡片、聊天页、列表：纹丝不动 ✗
```

排查了半天代码没找到"错"，最后才反应过来——**这压根不是写错，是我的主题方案根本没和系统挂钩**。要理解为什么，得先把资源体系补扎实。

---

## 二、先补基础：`$r` vs `$rawfile`

我 demo 里两种资源访问都用了：

```ts
$r('app.media.start')        // 小图标
$rawfile('images/1.png')     // 票根卡的大背景图
```

它们是两套完全不同的机制：

| | `$r('app.类型.名字')` | `$rawfile('路径')` |
|---|---|---|
| 找哪 | `resources/<限定符>/<类型>/` | `resources/rawfile/` 按路径原样读 |
| 编译期 | **编译进资源索引**，有数字 ID | 不编译，运行时按路径读 |
| 限定符自动切 | ✅ 支持（暗色 / 语言 / 分辨率） | ❌ 不支持 |
| 适合 | 图标、颜色、文字、尺寸 | 大图、HTML、JSON、字体等原始文件 |

**关键差异**：`$r` 能跟着暗色 / 语言 / 分辨率自动切，`$rawfile` 是死路径，切不了。

> 还有个细节：`$rawfile` 是按**当前模块**的 rawfile 目录找的。我那张 `images/1.png` 在 chat 模块，所以 chat 模块里的卡片能找到，entry 模块就找不到同一张。

---

## 三、resources 限定符目录（我只配了一半）

资源目录的命名规则是 `resources/<限定符>/<资源类型>/`。我 demo 现在的结构：

```text
resources/
├── base/              ← 默认兜底（限定符没命中时用这个）
│   ├── element/       ← color.json / string.json / float.json
│   ├── media/         ← 图片图标
│   └── profile/       ← 页面配置
├── dark/              ← ✗ 我没有！暗色专属资源
├── zh_CN/             ← ✓ 中文字符串
└── en_US/             ← ✓ 英文字符串
```

限定符可以多维度组合，匹配优先级大致是：

```text
语言(zh_CN) → 横竖屏 → 深浅色(dark) → 分辨率(hdpi/xhdpi…) → 设备(phone/tablet)
```

系统按当前环境**自动挑最匹配的目录**，挑不到就回退 `base`。这就是为什么我配了 `zh_CN` / `en_US` 后，系统语言一切换，App 文字就自动变——我一行切换代码都没写。

**但我漏配了 `dark` 目录**——这是后面 gap 的伏笔之一。

---

## 四、系统暗色：`resources/dark` 自动切，但有个铁律

正规的暗色做法是配两份 `color.json`：

```jsonc
// resources/base/element/color.json （亮色）
{ "color": [ { "name": "card_bg", "value": "#FFFFFF" } ] }

// resources/dark/element/color.json （暗色，同名不同值）
{ "color": [ { "name": "card_bg", "value": "#2C2C2E" } ] }
```

代码里用 `$r('app.color.card_bg')`，系统亮色取 base、暗色取 dark，**全自动**。

**但这里有条铁律**，是我这次最大的认知点：

```text
$r('app.color.xxx')  → 系统暗色自动切  ✓
硬编码 '#FFFFFF'      → 永远不变       ✗
```

去看我的 `ThemeState`：

```ts
get surface(): string {
  return this.isDark ? '#2C2C2E' : '#FFFFFF'   // 全是硬编码色值字符串
}
get textPrimary(): string {
  return this.isDark ? '#F2F2F7' : '#1C1C1E'
}
```

**全部是硬编码字符串**，没有一个走 `$r('app.color.xxx')`。所以系统的暗色限定符对我**完全无效**——这正是我必须手动管一个 `isDark` 的根本原因。

---

## 五、两套方案对比

到这里能看清，暗色其实有两条完全不同的路：

| | 我的 ThemeState（手动） | 系统 resources/dark |
|---|---|---|
| 颜色定义 | getter 里三元 `isDark ? A : B` | base + dark 两份 color.json |
| 切换 | 手动 `theme.isDark = true` | 系统自动 |
| 代码用法 | `this.theme.surface` | `$r('app.color.surface')` |
| App 内手动切主题 | ✅ 能（不跟系统也行） | ❌ 强制跟系统 |
| 跟随系统暗色 | ❓ 要自己监听 | ✅ 自动 |

我这套**更灵活**——能在 App 里做"主题开关"，不被系统绑死。代价是每个颜色要手写亮暗两个值，而且……**默认不跟系统走**。

---

## 六、定位 gap：为什么 demo 不跟系统

把链路画出来，问题一目了然：

```text
EntryAbility 设了 COLOR_MODE_NOT_SET（跟随系统）
   ↓
手机切暗色 → 系统级资源（$r、状态栏）跟着变
   ↓
但 ThemeState.isDark 是个独立 bool，默认 false
   ↓
而我的颜色全是 isDark ? A : B 的硬编码
   ↓
isDark 没人改它 → ✗ 卡片 / 页面颜色不变
```

**根因**：`setColorMode` 只让"系统资源"跟随系统，但我的颜色不是系统资源，是 `ThemeState.isDark` 控制的硬编码值。系统压根不知道 `ThemeState` 的存在，自然不会去改它的 `isDark`。

两者之间**缺一座桥**。

---

## 七、修复：监听系统配置变化，同步 isDark

`UIAbility` 有个 `onConfigurationUpdate(newConfig)` 回调——系统深浅色（以及语言、字号等）变化时会触发。在这里把系统的 `colorMode` 同步给 `ThemeState.isDark`，桥就搭好了。

改 `EntryAbility`，三处：

```ts
// ① import 补充
import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { WindowUtil, getThemeState } from 'common'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // ... 现有初始化
    this.context.getApplicationContext()
      .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)

    // ② 冷启动：读系统当前深浅色同步到全局主题
    //    （手机已经是暗色时，首屏就跟着暗，而不是先亮一下再变）
    this.syncTheme(this.context.config.colorMode)
  }

  // ③ 系统深浅色变化时回调，把 colorMode 同步给 ThemeState.isDark
  //    @Trace 驱动所有 this.theme.xxx 组件重渲
  onConfigurationUpdate(newConfig: Configuration): void {
    this.syncTheme(newConfig.colorMode)
  }

  /** 把系统 colorMode 映射成 ThemeState.isDark（undefined / 非暗色都按亮色处理） */
  private syncTheme(colorMode?: ConfigurationConstant.ColorMode): void {
    const isDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    getThemeState().isDark = isDark
  }
}
```

加上之后的链路：

```text
手机切暗色
   ↓
onConfigurationUpdate 触发
   ↓
syncTheme → getThemeState().isDark = true
   ↓
@Trace isDark 变化
   ↓
所有用 this.theme.xxx 的组件自动重渲 → ✓ 整个 App 跟着变暗
```

`onCreate` 里那次冷启动同步同样重要——否则手机本来就是暗色时，App 启动会"先亮一下，等到下一次配置变化才变暗"。

**两个关键点**：

1. **`getThemeState()` 必须是全局单例**。它内部走 `PersistenceV2.connect`，保证 EntryAbility 和所有组件拿到同一个 `ThemeState` 实例——否则 `@Trace` 改的是另一个实例，组件不会重渲。
2. **`syncTheme` 的参数设成可选**（`colorMode?`）。`undefined === COLOR_MODE_DARK` 是 `false`，天然按亮色处理，不会因为某次 config 缺字段而崩。

---

## 八、我学这块时的两个认知缺口

做自测题时暴露了两个我以为懂、其实没懂透的点：

### 缺口 1：以为"想换暗色图只能手动判路径"

`$rawfile` 的图确实不会自动切暗色（死路径），但我一开始只想到"代码里手动判 `isDark` 换路径"：

```ts
$rawfile(this.theme.isDark ? 'images/1_dark.png' : 'images/1.png')   // 方案一
```

漏了**更优的方案二**——把图从 rawfile 挪进 `media` 资源，改用 `$r`：

```text
resources/base/media/bg.png   ← 亮色版
resources/dark/media/bg.png   ← 暗色版（同名）
```
```ts
Image($r('app.media.bg'))   // 系统切暗色 → 自动取 dark 版
```

**一句话**：想让图自动跟暗色，就别用 rawfile，改成 `$r` 媒体资源。

### 缺口 2：以为"所有颜色配一个 json 就行"

我以为系统暗色就是"配一个 json 写死各种颜色，系统自动索引"。对**亮暗相同**的颜色（比如品牌色 `primary` 亮暗都是 `#007DFF`）确实只配 base 一份就够（暗色找不到回退 base）。

但模型有缺口：**亮暗不同的颜色要配两份**——`base/element/color.json` 和 `dark/element/color.json`，同名 `name`、不同 `value`，系统按 `colorMode` 自动挑。

**规则**：亮暗一样的色 → base 一份；亮暗不同的色 → base + dark 两份。

---

## 九、一句话心智模型

```text
$r 走资源索引，能跟限定符（暗色/语言/分辨率）自动切；
$rawfile 走死路径，啥都切不了；
硬编码色值不跟系统，$r + color.json 才自动；
手动主题方案（ThemeState）灵活，但要自己监听 onConfigurationUpdate 才跟系统。
```

---

## 十、顺口溜

```text
$r 进索引能切换，$rawfile 死路径；
base 兜底 dark 管暗，zh_CN 管中文；
硬编码色不跟系统，color.json 才自动；
ThemeState 灵活归灵活，配置回调搭起桥。
```

---

## 十一、参考

- [资源分类与访问（$r / $rawfile）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/resource-categories-and-access)
- [深色模式适配](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-adaptation-dark-mode)
- [Configuration / onConfigurationUpdate](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-app-ability-configuration)

---

## 十二、验证 & TODO

验证修复：

```text
1. 跑起来，手机设置切到深色模式
2. App 内容区（卡片 / 列表 / 页面）应该整体变暗
3. 切回浅色，应该跟着变亮
4. 看日志 syncTheme isDark=true/false 是否随系统切换打印
5. 手机本来就是暗色时冷启动 App，首屏应该直接是暗的（不闪一下亮色）
```

后续可做：

- [ ] 如果以后要加"App 内手动主题开关"，得加一个"是否跟随系统"标志位——否则冷启动的 `syncTheme` 会覆盖用户的手动选择
- [ ] 把票根卡里的硬编码蓝色抬头也接入 ThemeState，暗色下用更深的蓝
- [ ] 试着把一两个颜色改成 `$r('app.color.xxx')` + base/dark 两份 json，体会系统方案和手动方案的差异
