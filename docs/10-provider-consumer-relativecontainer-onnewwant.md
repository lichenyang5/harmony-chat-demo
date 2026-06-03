# 鸿蒙研读 10：@Provider/@Consumer、RelativeContainer、onNewWant

> 三个知识点放在一篇：跨层级状态共享、约束布局、Ability 复用生命周期。

---

## 一、@Provider / @Consumer：跨层级状态共享

### 1.1 解决什么问题

组件树很深的时候，祖先组件的状态要传给孙子组件，中间隔了好几层父子，每层都要写 `@Param` 透传，很烦：

```
GrandParent（持有 theme 状态）
  └─ Parent（只是透传，自己不用 theme）
       └─ Child（真正要用 theme 的地方）
```

`@Provider` / `@Consumer` 直接跳过中间层，等价于 React 的 `Context`。

### 1.2 基本语法

```typescript
// 祖先组件：提供数据
@ComponentV2
struct GrandParent {
  @Provider() theme: string = 'light'   // 提供，key 默认是属性名 'theme'

  build() {
    Parent()
  }
}

// 中间层：完全不需要感知 theme
@ComponentV2
struct Parent {
  build() {
    Child()   // 不用透传任何东西
  }
}

// 后代组件：消费数据
@ComponentV2
struct Child {
  @Consumer() theme: string = 'light'   // 消费，key 对上 'theme' 就能拿到

  build() {
    Text(`当前主题：${this.theme}`)
  }
}
```

**双向同步**：Child 修改 `this.theme`，GrandParent 里的值也会跟着变，反过来也一样。

### 1.3 别名匹配

当属性名不同时，用别名对齐：

```typescript
@Provider('currentTheme') theme: string = 'light'   // 提供方用别名 'currentTheme'

@Consumer('currentTheme') myTheme: string = 'light' // 消费方通过别名找到它
```

### 1.4 复杂对象类型

传对象的时候，必须配合 `@ObservedV2 + @Trace`，否则内部属性变化不会触发更新：

```typescript
@ObservedV2
class UserInfo {
  @Trace name: string = ''
  @Trace avatar: string = ''
}

@ComponentV2
struct App {
  @Provider() user: UserInfo = new UserInfo()
  // ...
}

@ComponentV2
struct ProfileCard {
  @Consumer() user: UserInfo = new UserInfo()

  build() {
    Text(this.user.name)   // user.name 变化时自动刷新
  }
}
```

### 1.5 注意事项

| 规则 | 说明 |
|------|------|
| 只能在 `@ComponentV2` 里用 | 在旧版 `@Component` 里会编译报错 |
| 类型必须一致 | Provider 和 Consumer 的类型要相同 |
| Consumer 要设默认值 | 找不到对应 Provider 时用默认值兜底，避免崩溃 |
| 不能从父组件传参给 Provider | `@Provider` 的值只能本地初始化 |
| 不能和 V1 混用 | V1 的 `@Provide/@Consume` 和 V2 的不互通 |

### 1.6 和 @Local / AppStorageV2 的区别

```
@Local          → 当前组件自用，不共享
@Provider/@Consumer → 组件树内共享，有层级关系（必须是祖先/后代）
AppStorageV2    → 全局共享，任何地方都能访问，无层级限制
```

选择依据：只在某棵子树里共享 → `@Provider/@Consumer`；整个 App 都要访问 → `AppStorageV2`。

---

## 二、RelativeContainer：约束布局

### 2.1 解决什么问题

`Column` / `Row` 是流式布局，适合线性排列。一旦遇到"图片左上角叠一个标签"、"按钮固定在某元素右边 8px"这类需求，流式布局要嵌套很多层才能实现。

`RelativeContainer` 是**约束布局**，每个子元素通过声明"我的左边对齐谁的右边"来定位，等价于 Android 的 `ConstraintLayout`。

### 2.2 核心规则：必须给 id

子元素之间要相互引用，所以每个子元素都必须设 `.id('唯一名称')`，**没有 id 的子元素不会被渲染**。

父容器本身的 id 固定写法是字符串 `'__container__'`。

### 2.3 alignRules 语法

```typescript
.alignRules({
  // 垂直方向
  top:    { anchor: '锚点id', align: VerticalAlign.Bottom },
  bottom: { anchor: '锚点id', align: VerticalAlign.Top },
  center: { anchor: '锚点id', align: VerticalAlign.Center },

  // 水平方向
  left:   { anchor: '锚点id', align: HorizontalAlign.End },
  right:  { anchor: '锚点id', align: HorizontalAlign.Start },
  middle: { anchor: '锚点id', align: HorizontalAlign.Center },
})
```

`anchor` 是参照物的 id，`align` 是自己的哪条边对齐到参照物的哪条边。

### 2.4 完整示例：头像 + 名字 + 标签

```typescript
RelativeContainer() {

  // 头像：相对父容器左上角定位
  Image($r('app.media.avatar'))
    .id('avatar')
    .width(48).height(48)
    .alignRules({
      top:  { anchor: '__container__', align: VerticalAlign.Top },
      left: { anchor: '__container__', align: HorizontalAlign.Start }
    })

  // 名字：在头像右边，垂直居中对齐
  Text('张三')
    .id('name')
    .alignRules({
      left:   { anchor: 'avatar', align: HorizontalAlign.End },   // 名字左边 = 头像右边
      center: { anchor: 'avatar', align: VerticalAlign.Center }   // 垂直居中对齐头像
    })
    .margin({ left: 8 })

  // VIP 标签：固定在头像右上角
  Text('VIP')
    .id('badge')
    .fontSize(10)
    .backgroundColor('#FFD700')
    .alignRules({
      bottom: { anchor: 'avatar', align: VerticalAlign.Top },     // 标签底部 = 头像顶部
      left:   { anchor: 'avatar', align: HorizontalAlign.End }    // 标签左边 = 头像右边
    })
    .offset({ x: -16, y: 4 })   // 微调让它叠在头像右上角
}
.width('100%')
.height(64)
```

### 2.5 常见陷阱

| 陷阱 | 原因 | 解法 |
|------|------|------|
| 子元素不显示 | 没有设置 `.id()` | 每个子元素都加 id |
| 全部子元素消失 | 两个元素互相依赖（A 依赖 B，B 又依赖 A）形成环 | 检查约束链，确保无循环 |
| 位置不对 | `align` 值选错了（水平/垂直方向混了）| 水平用 `HorizontalAlign`，垂直用 `VerticalAlign` |

### 2.6 什么时候选 RelativeContainer

```
子元素需要互相对齐        → RelativeContainer
元素需要叠加（绝对定位）   → Stack
单纯线性排列              → Column / Row
```

---

## 三、onNewWant：Ability 复用生命周期

### 3.1 先理解 UIAbility 启动模式

在 `module.json5` 里配置：

```json
{
  "abilities": [{
    "name": "EntryAbility",
    "launchType": "singleton"
  }]
}
```

| 模式 | 说明 |
|------|------|
| `singleton` | 全局只有一个实例，重复启动不新建 |
| `multiton` | 每次 `startAbility` 都新建一个实例（系统默认） |
| `specified` | 由开发者指定 key 决定复用还是新建 |

### 3.2 singleton 下的生命周期问题

`singleton` 模式下，Ability 已经在跑了，用户从别处（通知、桌面小组件、其他 App 的 deeplink）再次触发启动时：

```
第一次启动：  onCreate → onWindowStageCreate → onForeground（正常完整流程）

再次启动同一个 Ability：
  ❌ 不走 onCreate          ← 实例已存在，不会重新创建
  ❌ 不走 onWindowStageCreate
  ✅ 只走 onNewWant         ← 专门处理"带着新参数复用旧实例"的场景
```

### 3.3 典型场景

- 用户已经在 App 里，点推送通知跳到某个页面
- 桌面小组件点击，带参数打开 App 特定页
- 其他 App 通过 deeplink 唤起本 App

这些场景的共同点：App 已经在跑，但需要响应新的"意图"并跳转到对应页面。

### 3.4 代码实现

首先在 `module.json5` 配置 singleton：

```json
{
  "abilities": [{
    "name": "EntryAbility",
    "launchType": "singleton",
    "exported": true
  }]
}
```

然后在 EntryAbility 里实现 `onNewWant`：

```typescript
import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { HMRouterMgr } from '@hadss/hmrouter'

export default class EntryAbility extends UIAbility {

  // 第一次启动走这里
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 初始化全局服务、路由等
    this.handleWant(want)
  }

  // 实例已存在，再次被唤起走这里
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWant(want)   // 和 onCreate 处理一样的逻辑
  }

  private handleWant(want: Want): void {
    const targetPage = want.parameters?.['targetPage'] as string
    if (targetPage) {
      // 根据参数跳到对应页面
      HMRouterMgr.push({ pageUrl: targetPage })
    }
  }
}
```

### 3.5 为什么 onCreate 和 onNewWant 要写一样的逻辑

因为第一次冷启动走 `onCreate`，后续复用走 `onNewWant`——两条路都要能正确处理 `Want` 参数，所以把处理逻辑抽成私有方法，两个钩子都调用它。

如果只在 `onCreate` 里处理参数，复用时参数就丢了，这是新手最常踩的坑。

### 3.6 和路由 singleton 的区别

容易混淆的两个"单例"概念：

| | 作用域 | 控制的是什么 |
|---|---|---|
| `@HMRouter({ singleton: true })` | 路由栈 | 页面实例在路由栈里唯一 |
| `launchType: "singleton"` | 进程级别 | Ability 实例在整个 App 进程里唯一 |

前者是页面路由层面的复用，后者是 Ability（相当于 Android Activity）层面的复用，层级不同。

---

## 四、代码混淆

### 4.1 混淆是什么，为什么要做

发布到应用市场的包，任何人都可以反编译。混淆把代码里有意义的命名（类名、方法名、属性名）替换成无意义的短字符，提高逆向难度，同时也能减小包体积。

```
// 混淆前
class ChatViewModel {
  sendMessage(text: string) { ... }
}

// 混淆后（反编译看到的）
class a {
  b(c: string) { ... }
}
```

### 4.2 开启混淆：build-profile.json5

在模块的 `build-profile.json5` 里开启：

```json
{
  "buildOption": {
    "arkOptions": {
      "obfuscation": {
        "ruleOptions": {
          "enable": true,
          "files": ["./obfuscation-rules.txt"]
        }
      }
    }
  }
}
```

`enable: true` 才真正开启混淆，`files` 指向规则文件，可以配多个。

### 4.3 规则文件：obfuscation-rules.txt

规则文件分两类：**开启什么混淆** 和 **保留什么不混淆**。

**开启混淆的选项：**

```
-enable-property-obfuscation    # 混淆属性名（.name .id 这类）
-enable-toplevel-obfuscation    # 混淆顶层变量/类名
-enable-filename-obfuscation    # 混淆文件名
-enable-export-obfuscation      # 混淆导出的名称
-compact                        # 删除空白行和多余空格，减小体积
-remove-log                     # 删除所有 console.* 语句（生产环境去日志）
```

**保留不混淆的选项（-keep 系列）：**

```
-keep-property-name userId token   # 这些属性名保留原样
-keep-global-name MyClass          # 这些全局名称保留原样
```

**典型生产配置：**

```
-enable-property-obfuscation
-enable-toplevel-obfuscation
-compact
-remove-log

# 后端接口字段名不能混淆，否则序列化/反序列化对不上
-keep-property-name
  userId
  token
  pageUrl
  code
  message
  data
```

### 4.4 混淆和 HMRouter 的关系

HMRouter 通过 `pageUrl` 字符串在运行时查找页面，如果页面的类名、文件名被混淆了，路由就找不到对应页面——直接白屏或崩溃。

所以 HMRouter 提供了 `autoObfuscation` 配置来解决这个问题：

```json
// hmrouter_config.json
{
  "scanDir": ["src/main/ets/pages", "src/main/ets/dialogs"],
  "autoObfuscation": true
}
```

`autoObfuscation: true` 的作用：

```
编译时 HMRouter 插件自动扫描所有 @HMRouter 装饰的页面
  ↓
生成 hmrouter_obfuscation_rules.txt（路由相关类的白名单）
  ↓
自动追加到 build-profile.json5 的 files 列表里
  ↓
这些页面的类名/文件名在混淆时被保留，路由正常工作
```

如果手动设 `autoObfuscation: false`，就需要自己把 `hmrouter_obfuscation_rules.txt` 加进 `files` 列表，不然路由在开启混淆的 Release 包里必崩。

### 4.5 最容易踩的坑

| 场景 | 现象 | 原因 |
|------|------|------|
| Release 包路由跳转白屏 | Debug 正常，上架后崩 | 开了混淆但 HMRouter 白名单没配好 |
| 接口返回数据解析失败 | 字段全是 undefined | 接口字段名被混淆，和后端对不上 |
| 反序列化失败 | JSON.parse 后对象字段丢失 | Model 的属性名被混淆了 |

**规则**：和外部系统（后端接口、路由字符串、序列化）有交互的名称，一律加进 `-keep` 白名单。

---

## 五、四个知识点放一起看

| 知识点 | 解决的问题 | 类比 |
|--------|-----------|------|
| `@Provider/@Consumer` | 跨层级组件状态共享，跳过中间层透传 | React Context |
| `RelativeContainer` | 子元素互相约束定位，替代多层嵌套 | Android ConstraintLayout |
| `onNewWant` | Ability 已存在时响应新的启动意图 | Android `onNewIntent` |
| 代码混淆 | 保护源码 + 减小体积，需配合白名单保护路由和接口字段 | Webpack Terser + tree-shaking |

---

参考文档：
- [@Provider/@Consumer](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-provider-and-consumer)
- [RelativeContainer](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-layout-development-relative-layout)
- [UIAbility 启动模式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-launch-type)
- [ArkTS 代码混淆](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/source-obfuscation)
- [HMRouter autoObfuscation](https://gitee.com/hadss/hmrouter/blob/master/docs/Reference.md)
