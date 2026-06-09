# 鸿蒙 Stage 模型到底是什么？一篇讲清 Ability、EntryAbility 和入口文件为什么这么设计

> 面向刚开始做 HarmonyOS / ArkTS 的前端同学。本文尽量不用官网式术语堆叠，而是用“一个应用是怎么被系统启动、怎么创建窗口、怎么加载页面”的角度，把 Stage 模型、Ability、EntryAbility、WindowStage、页面入口这些概念串起来。

---

## 一、先给结论：HarmonyOS 不是“一个 React 框架”，而是“系统应用模型 + ArkUI 声明式 UI”

很多前端同学第一次看鸿蒙工程，会下意识拿 React 去类比：

```txt
React 项目：main.tsx -> App.tsx -> Router -> Page -> Component
鸿蒙项目：module.json5 -> EntryAbility.ets -> windowStage.loadContent('pages/Index') -> Page -> Component
```

这个类比**有帮助，但不能完全等价**。

更准确地说，鸿蒙开发分两层：

| 层级 | 负责什么 | 和 React 的关系 |
| --- | --- | --- |
| Ability Kit / Stage 模型 | 应用怎么被系统启动、生命周期怎么走、窗口怎么创建、页面怎么被加载 | 不是 React，更像系统层的应用运行框架 |
| ArkUI / ArkTS 声明式 UI | 页面怎么写、组件怎么组合、状态怎么驱动 UI 更新 | 这一层才更像 React 的声明式组件开发 |

所以你看到的 `EntryAbility.ets`、`UIAbility`、`WindowStage`，不要把它们理解成 React 组件。它们更像是系统给你的“应用启动和窗口生命周期入口”。真正接近 React 组件的，是 `pages/Index.ets` 里的 `@Entry`、`@Component`、`build()`。

一句话记住：

> **Ability 负责“应用怎么活着”，ArkUI 页面负责“界面怎么长出来”。**

---

## 二、Stage 模型解决的是什么问题？

HarmonyOS 应用不是简单地从一个 `main()` 函数开始跑，然后自己随便创建页面。它运行在操作系统里，系统必须知道：

- 这个应用有哪些入口？
- 点桌面图标时启动哪个能力？
- 应用切到后台时要通知谁？
- 窗口什么时候创建？
- 页面内容应该加载到哪个窗口？
- 卡片、分享、输入法、后台任务这类非普通页面能力由谁承载？

Stage 模型就是为这些问题设计的一套应用模型。

官方文档里说，Stage 模型提供了两类应用组件：`UIAbility` 和 `ExtensionAbility`。其中 `UIAbility` 是包含 UI 的应用组件，主要用于和用户交互；`ExtensionAbility` 面向特定扩展场景，比如卡片、输入法、闲时任务等。

对普通应用开发者来说，最常见的是这条链路：

```txt
系统启动应用
  ↓
加载 HAP / Module
  ↓
创建 AbilityStage（可选，Module 级初始化）
  ↓
创建 EntryAbility（UIAbility 的一个具体实现）
  ↓
创建 WindowStage
  ↓
loadContent('pages/Index')
  ↓
渲染 ArkUI 页面
```

这就是你在 DevEco Studio 里看到一堆入口文件的原因。

---

## 三、先把几个名字翻译成人话

### 1. Ability Kit 是什么？

`Ability Kit` 可以理解成 HarmonyOS 的“程序框架服务”。它提供应用组件模型、生命周期、组件间跳转、窗口承载、上下文能力等基础能力。

你可以把它看成鸿蒙应用的系统运行底座。

注意：Ability Kit 不是 UI 组件库。按钮、列表、文本、布局这些属于 ArkUI；而 Ability Kit 管的是应用组件、生命周期、窗口和上下文。

---

### 2. Stage 模型是什么？

Stage 模型是现在 HarmonyOS 主推的应用模型。你新建 ArkTS 工程时，默认就是 Stage 模型。

它的核心思想是：

> 把“应用组件”和“窗口管理”拆开，让应用能更好地适配多设备、多窗口、多形态。

以前很多移动端开发喜欢把“页面”和“窗口”和“生命周期”混在一个概念里。Stage 模型拆得更细：

```txt
UIAbility：负责应用组件生命周期
WindowStage：负责窗口舞台
ArkUI Page：负责真正的页面内容
```

这个拆分刚开始看起来绕，但好处是清晰：

- 应用生命周期归 UIAbility 管；
- 窗口相关能力归 WindowStage 管；
- 页面 UI 归 ArkUI 管；
- 模块级初始化可以放 AbilityStage；
- 特殊扩展能力交给 ExtensionAbility。

---

### 3. UIAbility 是什么？

`UIAbility` 是“带界面的应用组件”。

它不是一个页面，而是一个可以承载一组页面的应用组件。通常一个普通应用可以只有一个 `EntryAbility`，然后在里面用 `Navigation` 或路由管理多个页面。

你可以这样理解：

```txt
UIAbility ≈ 一个可被系统启动、可进入前后台、可创建窗口的 UI 运行单元
```

它负责的事情包括：

- 应用启动时初始化；
- 创建窗口舞台；
- 加载第一个页面；
- 监听前后台切换；
- 销毁时释放资源；
- 接收其他 Ability 启动传来的 Want 参数。

它不适合直接写页面 UI。真正的页面 UI 应该放到 `pages/xxx.ets` 和自定义组件里。

---

### 4. EntryAbility 是什么？

`EntryAbility` 不是一个特殊语法，而是工程模板默认生成的一个类名。

它通常长这样：

```ts
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // UIAbility 实例创建时回调
    // 这里适合做轻量级初始化
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 窗口舞台创建完成
    // 在这里加载第一个 ArkUI 页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'EntryAbility', 'Failed to load content. %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'EntryAbility', 'Succeeded in loading content.');
    });
  }

  onForeground(): void {
    // 应用进入前台
  }

  onBackground(): void {
    // 应用进入后台
  }

  onDestroy(): void {
    // UIAbility 销毁
  }
}
```

所以 EntryAbility 的本质是：

> **一个继承自 UIAbility 的默认入口 Ability。**

它叫 `EntryAbility`，是因为它通常是 `entry` 模块里的默认入口能力。你也可以创建其他 UIAbility，比如 `LoginAbility`、`ShareAbility`、`CameraAbility`，但大多数普通应用没必要拆这么多。

---

### 5. AbilityStage 是什么？

`AbilityStage` 是 Module 级别的组件管理器 / 组件容器。

一个 HAP 在首次加载时，可以创建一个 AbilityStage 实例。它适合做 Module 级初始化，比如：

- 初始化日志；
- 读取模块配置；
- 初始化一些模块级服务；
- 监听配置变化；
- 监听内存状态变化。

但是 DevEco Studio 默认工程不一定会自动生成 AbilityStage。新手阶段看不到它很正常。

如果把层级画出来，它大概在这里：

```txt
entry HAP / Module
  ├─ AbilityStage       // Module 级别，可选
  └─ EntryAbility       // UIAbility，真正负责启动 UI
      └─ WindowStage
          └─ pages/Index
```

一个非常实用的判断方式：

- **EntryAbility**：你几乎一定会用到，因为它要加载页面；
- **AbilityStage**：不是每个项目都必须手写，只有需要模块级初始化时再加。

---

### 6. WindowStage 是什么？

`WindowStage` 可以直译成“窗口舞台”。

它不是页面，而是 UIAbility 拥有的窗口管理对象。UIAbility 创建后，系统会给它创建一个 WindowStage，然后你才能把 ArkUI 页面加载进去。

最关键的一句代码就是：

```ts
windowStage.loadContent('pages/Index')
```

它的意思不是“跳转到 Index 页面”，而是：

> 把 `pages/Index` 这个 ArkUI 页面加载到当前 UIAbility 的主窗口里，作为启动内容。

所以 `EntryAbility.ets` 本身不画界面，它只是告诉系统：窗口准备好了，先把哪个页面放进去。

---

### 7. Page、@Entry、@Component 又是什么？

`pages/Index.ets` 通常长这样：

```ts
@Entry
@Component
struct Index {
  @State message: string = 'Hello HarmonyOS';

  build() {
    Column() {
      Text(this.message)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

这里才是你熟悉的声明式 UI 开发。

可以这样理解：

| 鸿蒙概念 | 通俗理解 |
| --- | --- |
| `@Entry` | 这个组件可以作为一个页面入口 |
| `@Component` | 这是一个 ArkUI 自定义组件 |
| `struct Index` | 页面组件本体 |
| `build()` | 描述 UI 长什么样 |
| `@State` | 页面内部状态，变化后驱动 UI 刷新 |

这一层才比较像 React：

```txt
React：function App() { return <div>Hello</div> }
ArkUI：build() { Column() { Text('Hello') } }
```

区别是 ArkUI 用的是 ArkTS 声明式 DSL，不是 JSX。

---

## 四、一个鸿蒙应用从点击图标到展示页面，到底发生了什么？

假设你新建了一个最普通的 HarmonyOS 工程，它通常会有这些文件：

```txt
AppScope/
  app.json5

entry/
  src/main/
    module.json5
    ets/
      entryability/
        EntryAbility.ets
      pages/
        Index.ets
    resources/base/profile/
      main_pages.json
```

启动流程可以拆成 6 步。

---

### 第 1 步：系统读取应用全局配置 app.json5

`AppScope/app.json5` 是应用级配置，描述的是整个应用的信息，比如包名、版本、图标、标签等。

它不是页面入口，但它告诉系统：这个应用是谁。

可以粗略理解成：

```txt
app.json5 = 应用身份证
```

---

### 第 2 步：系统读取模块配置 module.json5

`entry/src/main/module.json5` 是模块配置。

这里会声明：

- 当前模块叫什么；
- 当前模块类型是什么，常见是 `entry`；
- 有哪些 Ability；
- 默认入口 Ability 是谁；
- Ability 的代码文件在哪里；
- 图标、标签、启动窗口背景等配置。

简化后大概类似这样：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "mainElement": "EntryAbility",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:icon",
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:startIcon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true
      }
    ]
  }
}
```

这里最重要的是两层信息：

```txt
mainElement: EntryAbility
abilities[].srcEntry: ./ets/entryability/EntryAbility.ets
```

翻译成人话就是：

> 当前模块的默认入口能力叫 EntryAbility，它的代码文件在 `entryability/EntryAbility.ets`。

---

### 第 3 步：系统创建 EntryAbility 实例

系统根据 `module.json5` 找到 `EntryAbility.ets`，然后创建这个类的实例。

于是会触发：

```ts
onCreate(want, launchParam)
```

`onCreate()` 表示 UIAbility 对象已经创建完成。

这里可以做轻量初始化，比如：

- 初始化日志；
- 读取启动参数；
- 准备基础数据结构；
- 设置应用级配置。

不建议在这里做耗时任务，比如大量文件读写、复杂网络请求、长时间阻塞计算。因为启动阶段越重，用户看到首屏越慢。

---

### 第 4 步：系统创建 WindowStage

UIAbility 创建后，系统会继续创建 WindowStage。

WindowStage 创建完成后，触发：

```ts
onWindowStageCreate(windowStage)
```

这一步非常关键，因为它是“窗口准备好了”的信号。

你通常会在这里写：

```ts
windowStage.loadContent('pages/Index')
```

它告诉系统：

> 当前窗口的第一个页面内容，从 `pages/Index` 加载。

---

### 第 5 步：系统检查 main_pages.json

`loadContent('pages/Index')` 不是随便写一个路径就行。

这个页面路径通常需要在 `resources/base/profile/main_pages.json` 里声明。

大概类似：

```json
{
  "src": [
    "pages/Index"
  ]
}
```

所以这两个地方要对应上：

```ts
windowStage.loadContent('pages/Index')
```

```json
{
  "src": ["pages/Index"]
}
```

如果你新增了页面，但路由或加载时找不到，有时就要检查页面是否被正确配置、路径是否写错、大小写是否一致。

---

### 第 6 步：渲染 pages/Index.ets

最后，系统加载 `pages/Index.ets`，找到带 `@Entry` 的页面组件，然后执行它的 `build()`，渲染 UI。

于是你终于看到了界面。

整个过程串起来就是：

```txt
点击桌面图标
  ↓
app.json5：识别应用
  ↓
module.json5：找到入口 Ability
  ↓
EntryAbility.ets：创建 UIAbility
  ↓
onWindowStageCreate：窗口创建完成
  ↓
loadContent('pages/Index')：加载页面
  ↓
main_pages.json：确认页面路径
  ↓
Index.ets：执行 build() 渲染界面
```

这就是“入口文件为什么这样设计”的核心原因：

> 鸿蒙不是只启动一个前端页面，而是先让系统创建应用组件，再创建窗口，再把 ArkUI 页面加载进窗口。

---

## 五、和 React 项目怎么类比？

为了方便理解，可以临时这样类比：

| React / Web | HarmonyOS / ArkTS | 是否完全等价 |
| --- | --- | --- |
| `index.html` | 系统窗口 / WindowStage | 不完全等价 |
| `main.tsx` | `EntryAbility.ets` 的 `loadContent()` | 部分类似，都是把 UI 挂到入口上 |
| `App.tsx` | `pages/Index.ets` 或应用根页面 | 比较接近 |
| React Router | `router` / `Navigation` | 比较接近 |
| React Component | `@Component struct` | 比较接近 |
| React state/hooks | `@State` / `@Prop` / 状态管理 V1/V2 | 思想接近，语法不同 |
| 浏览器生命周期 | UIAbility 生命周期 | 不等价，UIAbility 更偏系统组件生命周期 |

一个更形象的类比是：

```txt
React 应用：
浏览器给你一个 DOM 节点，你把 App 挂上去。

HarmonyOS 应用：
系统先创建 UIAbility，再创建 WindowStage，你再把 ArkUI Page 加载到窗口里。
```

所以，`EntryAbility` 不是 `App.tsx`。

更准确地说：

```txt
EntryAbility ≈ 系统入口 + 生命周期管理 + 首屏挂载器
pages/Index ≈ App.tsx / 首页根组件
自定义 @Component ≈ React 组件
Navigation/router ≈ React Router
```

---

## 六、EntryAbility 里每个生命周期到底该做什么？

新手很容易把所有代码都塞进 `EntryAbility`。这不推荐。

可以按这个规则分配职责。

### 1. onCreate：做轻量初始化

```ts
onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  // 适合：读取启动参数、初始化日志、准备轻量对象
}
```

适合放：

- 日志初始化；
- 应用配置初始化；
- 读取 Want 参数；
- 初始化轻量服务。

不适合放：

- 首屏 UI 代码；
- 大量网络请求；
- 大文件读写；
- 耗时计算。

---

### 2. onWindowStageCreate：加载首屏页面

```ts
onWindowStageCreate(windowStage: window.WindowStage): void {
  windowStage.loadContent('pages/Index');
}
```

适合放：

- `loadContent()` 加载首屏；
- 主窗口设置；
- 窗口事件监听；
- 沉浸式窗口等窗口级配置。

这是 EntryAbility 里最常见、最重要的函数。

---

### 3. onForeground：回到前台

```ts
onForeground(): void {
  // 应用进入前台
}
```

适合放：

- 刷新轻量数据；
- 恢复前台相关资源；
- 重新检查登录态；
- 恢复动画或传感器监听。

---

### 4. onBackground：进入后台

```ts
onBackground(): void {
  // 应用进入后台
}
```

适合放：

- 保存草稿；
- 暂停定位、传感器、播放器；
- 释放不必要的内存；
- 记录埋点。

---

### 5. onDestroy：销毁

```ts
onDestroy(): void {
  // Ability 销毁
}
```

适合放：

- 释放全局资源；
- 取消监听；
- 关闭连接；
- 清理缓存引用。

---

## 七、常见误区：别把 EntryAbility 当页面组件用

### 误区 1：在 EntryAbility 里写页面状态

不建议这样做：

```ts
export default class EntryAbility extends UIAbility {
  messageList: ChatMessage[] = [] // 不推荐把普通页面 UI 数据放这里
}
```

页面数据应该优先放在页面组件、ViewModel、状态管理对象或持久化层里。

EntryAbility 更像生命周期入口，不是页面状态容器。

---

### 误区 2：每个页面都建一个 UIAbility

React 里每个页面是一个路由页面。鸿蒙里不要简单理解成“每个页面都要一个 Ability”。

普通应用通常这样就够了：

```txt
一个 EntryAbility
  └─ 一个 ArkUI 根页面
      └─ Navigation / router 管理多个业务页面
```

什么时候需要多个 UIAbility？

- 你需要多个独立任务入口；
- 你需要不同的启动模式；
- 你需要被外部明确拉起不同能力；
- 你有非常独立的窗口级业务。

但对大多数新手项目、练习 demo、聊天应用来说：

> **一个 EntryAbility + 页面路由，就够了。**

---

### 误区 3：以为 @Entry 就是应用入口

`@Entry` 是 ArkUI 页面入口，不是系统应用入口。

真正的系统入口链路是：

```txt
module.json5 -> EntryAbility.ets -> windowStage.loadContent('pages/Index') -> @Entry 页面
```

所以：

- `EntryAbility` 是系统应用组件入口；
- `@Entry` 是 ArkUI 页面入口。

这两个“入口”不是同一层东西。

---

## 八、UIAbility、ExtensionAbility、AbilityStage 怎么选？

### 1. 普通页面应用：用 UIAbility

只要你要展示完整页面、和用户交互，就用 `UIAbility`。

例如：

- 聊天页面；
- 首页；
- 登录页；
- 设置页；
- 订单详情页。

但这些页面不一定都对应不同 UIAbility。多数时候它们只是同一个 UIAbility 里的不同页面。

---

### 2. 桌面卡片、输入法、后台扩展：用 ExtensionAbility 派生类

`ExtensionAbility` 不是普通页面能力。它更偏系统扩展场景。

例如：

- 桌面服务卡片：`FormExtensionAbility`；
- 输入法：`InputMethodExtensionAbility`；
- 闲时任务：`WorkSchedulerExtensionAbility`；
- 其他系统规定的扩展能力。

普通应用开发时，不要随便自定义 ExtensionAbility。通常根据官方给定的派生能力使用。

---

### 3. Module 级初始化：用 AbilityStage

如果你需要在某个 HAP / Module 首次加载时做初始化，可以考虑 AbilityStage。

比如：

```ts
import { AbilityStage } from '@kit.AbilityKit';

export default class MyAbilityStage extends AbilityStage {
  onCreate(): void {
    // Module 首次加载时初始化
  }
}
```

然后在 `module.json5` 里通过 `srcEntry` 指到这个 AbilityStage 文件。

新手阶段可以先不手写 AbilityStage，理解它是“模块级初始化入口”即可。

---

## 九、为什么鸿蒙不直接从 Index.ets 启动？

这是很多前端同学最困惑的地方。

React 项目里，入口一般很直接：

```ts
createRoot(document.getElementById('root')).render(<App />)
```

于是你会觉得鸿蒙也应该这样：

```txt
直接启动 pages/Index.ets 不就行了吗？
```

但操作系统应用比 Web 页面复杂。系统不只是要渲染页面，还要管理：

- 应用生命周期；
- 多窗口；
- 前后台切换；
- 任务栈；
- 应用被外部拉起；
- 权限和上下文；
- 启动参数 Want；
- 资源释放；
- 多设备形态。

所以鸿蒙需要先有一个系统可管理的应用组件，也就是 UIAbility。

`Index.ets` 只是 UI 内容，系统不能只靠它管理整个应用生命周期。

因此设计成：

```txt
系统管理 UIAbility
UIAbility 管理 WindowStage
WindowStage 加载 ArkUI 页面
ArkUI 页面渲染组件树
```

这个设计的好处是职责清楚：

| 职责 | 交给谁 |
| --- | --- |
| 应用组件生命周期 | UIAbility |
| 模块初始化 | AbilityStage |
| 窗口承载和窗口事件 | WindowStage |
| 页面 UI | ArkUI Page |
| 业务组件 | @Component |
| 页面跳转 | router / Navigation |

---

## 十、用一个“剧场”比喻彻底记住

可以把 HarmonyOS Stage 模型想成一个剧场：

```txt
应用 App：整家剧院
Module / HAP：一个演出厅
AbilityStage：演出厅管理员
UIAbility / EntryAbility：一场具体演出的负责人
WindowStage：舞台
pages/Index：第一幕剧本
@Component：演员和道具
build()：把演员和道具摆上舞台的过程
```

点击桌面图标时：

```txt
观众入场
  ↓
剧院找到今天要演哪个厅
  ↓
演出负责人 EntryAbility 到场
  ↓
舞台 WindowStage 搭好
  ↓
加载第一幕 pages/Index
  ↓
演员组件开始表演
```

这样理解就不绕了。

---

## 十一、新手项目应该怎么组织？

如果你现在做的是一个 AI 聊天 demo、普通业务 App、练习项目，可以先用这套结构：

```txt
entry/src/main/ets/
  entryability/
    EntryAbility.ets          // 只放生命周期、窗口加载、全局轻量初始化

  pages/
    Index.ets                 // 应用首页或根容器
    ChatPage.ets              // 聊天页面
    SettingsPage.ets          // 设置页面

  components/
    ChatBubble.ets
    PickupConfirmCardComp.ets

  model/
    ChatMessage.ets
    CardData.ets

  viewmodel/
    ChatViewModel.ets

  utils/
    Logger.ets
    StorageUtil.ets
```

分工建议：

| 文件 | 放什么 |
| --- | --- |
| `EntryAbility.ets` | 生命周期、`loadContent`、窗口配置 |
| `pages/Index.ets` | 根页面、首页布局、导航容器 |
| `pages/ChatPage.ets` | 聊天页面主体 |
| `components/*` | 可复用 UI 组件 |
| `model/*` | 数据结构 |
| `viewmodel/*` | 页面业务状态和逻辑 |
| `utils/*` | 工具函数 |

一个非常实用的原则：

> **EntryAbility 越薄越好，业务逻辑尽量下沉到页面、组件、ViewModel 和服务层。**

---

## 十二、读官网文档时建议按这个顺序看

官网文档比较完整，但新手直接从目录一路看容易迷路。建议按这个顺序：

1. 先看 Stage 模型开发概述，建立整体层级；
2. 再看 UIAbility 组件概述，理解 UIAbility 是什么；
3. 然后看 UIAbility 生命周期，理解 `onCreate`、`onWindowStageCreate`、`onForeground`、`onBackground`；
4. 接着看 UIAbility 基本用法，重点看 `windowStage.loadContent()`；
5. 最后看 `module.json5` 配置文件，理解入口 Ability 是怎么声明的。

不要一开始就钻进启动模式、多进程、跨设备拉起、ExtensionAbility 细节。先把普通应用启动链路吃透，再往后看。

---

## 十三、最后总结

鸿蒙 Stage 模型看起来概念多，是因为它把系统应用运行链路拆得比较细：

```txt
App -> Module/HAP -> AbilityStage -> UIAbility/EntryAbility -> WindowStage -> Page -> Component
```

新手最需要记住的是这几句话：

1. `EntryAbility` 不是页面，它是默认入口 `UIAbility`。
2. `UIAbility` 负责应用组件生命周期，不负责具体 UI 细节。
3. `WindowStage` 是窗口舞台，`loadContent()` 把页面加载到窗口里。
4. `pages/Index.ets` 里的 `@Entry + @Component + build()` 才是你真正写 UI 的地方。
5. ArkUI 的声明式组件开发和 React 思想接近，但 Ability 层不是 React。
6. 普通项目通常一个 `EntryAbility` 就够，页面跳转交给 `Navigation` 或 `router`。
7. `EntryAbility.ets` 要尽量薄，不要堆业务逻辑。

把这条链路想明白之后，再去看状态管理、路由、窗口、ExtensionAbility，就不会觉得官网目录是一堆孤立名词了。

---

## 参考资料

- HarmonyOS 官方文档：Stage模型开发指导 / Stage模型开发概述  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/stage-model-development-overview
- HarmonyOS 官方文档：UIAbility组件概述  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-overview
- HarmonyOS 官方文档：UIAbility组件生命周期  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-lifecycle
- HarmonyOS 官方文档：UIAbility组件基本用法  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-usage
- HarmonyOS 官方文档：AbilityStage组件管理器  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/abilitystage
- HarmonyOS 官方文档：module.json5配置文件  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/module-configuration-file
