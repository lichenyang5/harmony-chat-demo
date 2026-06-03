# 鸿蒙路由研读：为什么公司项目用 HMRouterMgr 而不用原生 Navigation

> 入职后看代码，满屏都是 `HMRouterMgr.push()`、`@HMRouter({ pageUrl: ... })`，完全不是官方文档里教的写法。这篇博客就是搞清楚：原生路由有什么问题，HMRouterMgr 又解决了什么。

---

## 一、先搞清楚鸿蒙的三种包类型

在理解路由问题之前，必须先理解鸿蒙的模块体系，否则"为什么要跨模块"这件事讲不清楚。

| 包类型 | 全称 | 关键特征 |
|--------|------|----------|
| **HAP** | HarmonyOS Ability Package | 用户安装的主体，每个 HAP 是一个独立的可交付单元 |
| **HAR** | HarmonyOS Archive | 静态库，**编译期打进 HAP**，体积叠加，不能按需下载 |
| **HSP** | HarmonyOS Shared Package | 动态共享包，**运行时按需下载**，不影响首包体积 |

一个中大型鸿蒙项目的目录结构里通常有 `features/sdk_a`、`features/sdk_b`、`business/service` 等大量模块，每个都是独立的 HAR 或 HSP。

**HSP 的核心价值**：把不常用的功能（某个三方 SDK 集成页、某个特殊业务页）拆成 HSP，用户安装时只下载主包，用到该功能时才触发下载。首包体积可以从 200MB 压缩到 30MB，这对上架至关重要。

这就是"分很多模块"的根本动机：**减小首包体积 + 按需加载**。

---

## 二、原生路由方案及其问题

### 2.1 旧版 `router`（API 8 时代）

```typescript
// 跳转
router.pushUrl({ url: 'pages/DetailPage', params: { id: 123 } })

// 返回
router.back()

// 接收参数
let params = router.getParams() as Record<string, Object>
```

**致命问题**：`router` 只能访问同一个 HAP 内的页面，完全无法跨模块。在单模块小应用里能用，稍微复杂一点就废了。

---

### 2.2 新版 `Navigation`（API 10+ 推荐方案）

鸿蒙在 API 10 推出了 `Navigation` 组件，思路更接近 Web 里的嵌套路由：

```typescript
// 在根页面声明路由容器和路由表
@Entry
@Component
struct EntryPage {
  pathStack: NavPathStack = new NavPathStack()

  @Builder
  pageMap(name: string) {
    if (name === 'DetailPage') {
      DetailPage()
    } else if (name === 'ListPage') {
      ListPage()
    }
    // 每加一个页面这里就要加一个 if 分支
  }

  build() {
    Navigation(this.pathStack) {
      // 首页内容
    }
    .navDestination(this.pageMap)  // 路由表必须在这里静态声明
  }
}
```

```typescript
// 跳转
this.pathStack.pushPathByName('DetailPage', { id: 123 })

// 返回
this.pathStack.pop()
```

表面上看没什么问题，但在**多模块架构下会出现根本性问题**。

---

## 三、多模块场景下原生 Navigation 为什么失效

### 3.1 问题复现

假设项目拆成了三个模块：

```
主包 entry/
  └─ pages/MainPage.ets

HSP features/sdk_a/
  └─ pages/SdkAPage.ets   ← 三方 SDK A 集成页

HSP features/sdk_b/
  └─ pages/SdkBPage.ets   ← 三方 SDK B 集成页
```

要在 `entryPage` 的 `navDestination` 里注册子模块页面，就必须 import 它们：

```typescript
// entry/pages/EntryPage.ets
import { SdkAPage } from 'sdk_a'   // ← 这里 import 了 HSP
import { SdkBPage } from 'sdk_b'   // ← 这里也 import 了 HSP

@Builder
pageMap(name: string) {
  if (name === 'SdkAPage') {
    SdkAPage()   // 编译期就把 HSP 代码拉进来了
  }
  if (name === 'SdkBPage') {
    SdkBPage()
  }
}
```

**这样做直接破坏了 HSP 的按需加载**：

- 主包 import 了 HSP 的组件 → 编译器把 HSP 代码静态打进主包 → HSP 退化成了 HAR → 首包体积暴增
- 每加一个子模块页面，都要回来改 entryPage 的路由表 → 模块之间产生硬依赖 → 模块化失去意义

### 3.2 问题的本质

```
原生 Navigation 的路由表 = 编译期静态代码
HSP 的按需加载      = 运行时动态行为

两者从根上就是矛盾的。
```

主包在**编译期**必须知道所有目标页面，但 HSP 页面在**运行时**才加载进来——这两件事无法同时成立。

---

## 四、HMRouterMgr 怎么解决这个问题

[HMRouter](https://gitee.com/hadss/hmrouter) 是华为官方出品的路由框架（`@hadss/hmrouter`），核心思路是：**用代码生成替代静态声明，把路由注册推迟到运行时。**

### 4.1 每个模块自己声明自己：`hmrouter_config.json`

每个模块根目录放一个配置文件，告诉编译工具"扫描哪些目录找页面"：

```json
// features/sdk_a/hmrouter_config.json
{
  "scanDir": [
    "src/main/ets/pages",
    "src/main/ets/dialogs",
    "src/main/ets/interceptors",
    "src/main/ets/anim"
  ],
  "saveGeneratedFile": false,
  "autoObfuscation": true,
  "defaultPageTemplate": "../templates/PageAndDialogTemplate.ejs"
}
```

```json
// 主包 hmrouter_config.json 同理，扫自己的目录
{
  "scanDir": [
    "src/main/ets/v3/pages",
    "src/main/ets/pages",
    "src/main/ets/dialogs",
    "src/main/ets/interceptors",
    "src/main/ets/lifecycle",
    "src/main/ets/anim"
  ]
}
```

**关键点**：每个模块只扫自己的目录，模块之间互不知晓。

### 4.2 页面用装饰器声明自己：`@HMRouter`

```typescript
// features/sdk_a/src/main/ets/pages/SdkAPage.ets
import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'

@HMRouter({ pageUrl: AppPageConstant.SdkAPage })  // ← 页面自报家门
@ComponentV2
export struct SdkAPage {
  // ...
}
```

`@HMRouter` 的参数选项：

```typescript
// 普通页面
@HMRouter({ pageUrl: 'app://sdk_a_page' })

// 单例页面（整个路由栈里只存一个实例）
@HMRouter({ pageUrl: 'app://some_page', singleton: true })

// 弹窗页面（走路由栈但展示为对话框）
@HMRouter({ pageUrl: 'app://search_dialog', singleton: true, dialog: true })

// 非单例（明确声明每次 push 都是新实例）
@HMRouter({ pageUrl: 'app://detail_page', singleton: false })
```

### 4.3 编译期：代码生成工具生成注册代码

HMRouter 的 Hvigor 插件在构建阶段扫描所有模块的配置和 `@HMRouter` 装饰器，**为每个模块单独生成路由注册文件**：

```
构建阶段自动生成（你看不到，但它在）:

sdk_a 模块生成:
  → registerRoute('app://sdk_a_page', () => SdkAPage)

sdk_b 模块生成:
  → registerRoute('app://sdk_b_page', () => SdkBPage)

主包不需要 import 任何子模块组件
```

### 4.4 运行时：HSP 加载时路由表自动合并

```
用户点击功能入口
  ↓
系统下载并加载 HSP 模块
  ↓
HSP 模块初始化时，注册代码执行，把自己的路由注入全局路由表
  ↓
HMRouterMgr.push({ pageUrl: 'app://sdk_a_page' }) 就能找到这个页面了
```

主包全程只知道一个**字符串**（pageUrl），不需要任何编译期的 import 依赖。这就是"解耦"的实现方式。

---

## 五、HMRouterMgr 常用 API

理解了原理，再看 API 就很直观了。

### 5.1 页面跳转：push / pop / replace

```typescript
// 跳转到新页面，可传参数
HMRouterMgr.push({ pageUrl: AppPageConstant.SdkAPage, param: { url: 'https://...' } })

// 返回上一页
HMRouterMgr.pop()

// 跳过中间层返回（skipedLayerNumber=1 表示跳过一层）
HMRouterMgr.pop(undefined, 1)

// 替换当前页面（不留历史，用于登录后跳首页这种场景）
HMRouterMgr.replace({ pageUrl: AppPageConstant.HomePage })
```

实际项目中通常会封装一层 `HMUtil` 工具类，让调用更统一：

```typescript
export class HMUtil {
  static push(pathInfo: HMRouterPathInfo, callback?: HMRouterPathCallback): void {
    HMRouterMgr.push(pathInfo, callback)
  }
  static replace(pathInfo: HMRouterPathInfo, callback?: HMRouterPathCallback): void {
    HMRouterMgr.replace(pathInfo, callback)
  }
  static pop(pathInfo?: HMRouterPathInfo, skipedLayerNumber?: number): void {
    HMRouterMgr.pop(pathInfo, skipedLayerNumber)
  }
}
```

### 5.2 接收路由参数：getCurrentParam

```typescript
aboutToAppear(): void {
  // 获取上一个页面 push 时传过来的 param
  const param = HMRouterMgr.getCurrentParam() as ESObject
  const url = param?.['url']  // 取出 url 字段
  this.viewModel.init({ info: { url } })
}
```

对比原生 Navigation：

```typescript
// 原生方式：需要在 NavDestination 的 onReady 回调里拿，跟生命周期耦合
.onReady((ctx: NavDestinationContext) => {
  const param = ctx.pathInfo.param as ESObject
})
```

HMRouter 的 `getCurrentParam()` 可以在 `aboutToAppear` 里直接调用，跟普通成员变量初始化一样自然。

### 5.3 页面生命周期监听：getCurrentLifecycleOwner

这是 HMRouter 最有价值的能力之一，**让组件能感知自己在路由栈里的显示/隐藏状态**：

```typescript
aboutToAppear(): void {
  // 页面被 push 进来显示时触发（包括从下层页面 pop 回来）
  HMRouterMgr.getCurrentLifecycleOwner()?.addObserver(HMLifecycleState.onShown, () => {
    this.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)  // 当前页启用压缩模式
  })

  // 页面被新页面覆盖（hidden）时触发
  HMRouterMgr.getCurrentLifecycleOwner()?.addObserver(HMLifecycleState.onHidden, () => {
    this.setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)  // 恢复上抬模式
  })
}
```

封装成更简洁的 `HMUtil` 工具方法后：

```typescript
// 使用封装后的 API
HMUtil.bindPageController(this.controller)  // 一行绑定所有生命周期

// bindPageController 内部做的事：
static bindPageController(controller: BaseController) {
  HMUtil.onPageShow(ctx => controller.onPageShow(ctx))
  HMUtil.onPageHide(ctx => controller.onPageHide(ctx))
  HMUtil.onBackPressed(ctx => controller.onBackPress(ctx))
}
```

原生 `Navigation` 没有这个能力，子页面无法感知自己是否在栈顶，只能靠 `onAppear/onDisappear`，但那两个钩子在 push 新页面时不会触发（当前页还在 DOM 里，只是被遮住了）。

### 5.4 拦截器：路由守卫

```typescript
class AuthInterceptor implements IHMInterceptor {
  handle(info: HMInterceptorInfo): HMInterceptorAction {
    // 做登录检查、权限校验等
    if (!isLoggedIn()) {
      HMRouterMgr.push({ pageUrl: AppPageConstant.LoginPage })
      return HMInterceptorAction.DO_REJECT  // 拦截，不再继续跳转
    }
    return HMInterceptorAction.DO_NEXT     // 放行，继续走原路由
  }
}
```

拦截器通过 `@HMInterceptor` 装饰器注册，等价于 Vue Router 里的 `router.beforeEach`，但原生 Navigation 完全没有对应机制。

---

## 六、完整对比总结

| 能力 | 原生 router | 原生 Navigation | HMRouterMgr |
|------|------------|----------------|-------------|
| 跨模块（HAR/HSP）| ❌ 不支持 | ❌ 实现复杂，破坏 HSP 按需加载 | ✅ 原生支持 |
| 声明方式 | 字符串 URL | Builder 函数静态注册 | `@HMRouter` 装饰器自动发现 |
| 参数获取 | `getParams()` | `onReady` 回调 | `getCurrentParam()` 随时调用 |
| 单例页面 | ❌ | ❌ | ✅ `singleton: true` |
| 弹窗路由 | ❌ | 需手动实现 | ✅ `dialog: true` |
| 路由守卫/拦截器 | ❌ | ❌ | ✅ `IHMInterceptor` |
| 页面显示/隐藏生命周期 | ❌ | ❌ | ✅ `onShown/onHidden` |
| 自定义转场动画 | ❌ | 有限支持 | ✅ `BottomDialogAnimator` 等 |

---

## 七、一句话结论

**原生 Navigation 的路由表是编译期静态代码，HSP 的按需加载是运行时动态行为，两者天然矛盾。** HMRouterMgr 用"扫描目录 → 代码生成 → 运行时注入"的方式，让每个模块只声明自己、互不依赖，主包只认字符串 pageUrl，彻底解决了多模块路由问题。

顺带还补齐了拦截器、单例、弹窗路由、页面生命周期感知等原生 Navigation 缺失的能力，所以公司在多模块项目里用它是合理选择。
