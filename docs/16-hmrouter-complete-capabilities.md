# HMRouter 完整能力清单：从初始化到拦截器/对话框/生命周期/转场动画一站式查阅

> 项目：`MyApplication`
> 模块：`entry`（HAP）+ `chat`（HAR） + `common`（HAR）
> 路由库版本：`@hadss/hmrouter`（gitee.com/hadss/hmrouter）
> 已有相关博客：
> - [09-hmrouter-vs-native-navigation.md](./09-hmrouter-vs-native-navigation.md) ← HMRouter vs 原生 NavPathStack 对比
> - [11-hmrouter-interceptor-dialog-lifecycle.md](./11-hmrouter-interceptor-dialog-lifecycle.md) ← 拦截器 / Dialog / 生命周期入门
> - [12-provider-consumer-and-har-multi-module.md](./12-provider-consumer-and-har-multi-module.md) ← HAR 多模块下 HMRouter 注册的约束
>
> 本篇定位：**完整能力清单 + 工程现场速查表**。前面的博客是"为什么"、"入门思路"，本篇是"我现在要找 push 第三个参数怎么写"、"拦截器 priority 怎么定"、"页面声明周期到底有哪些"，**直接查表型**。

---

## 〇、能力地图（一张图查全部）

```text
┌──────────────────────────────── HMRouter 全景 ────────────────────────────────┐
│                                                                              │
│  【① 三件套】                                                                 │
│   ├ Index.ets         HMNavigation 容器（路由舞台）                            │
│   ├ EntryAbility.ets  HMRouterMgr.init / openLog / registerGlobalInterceptor │
│   └ hmrouter_config.json  scanDir 编译期扫描目录                              │
│                                                                              │
│  【② 装饰器】                                                                 │
│   ├ @HMRouter        页面/Dialog 注册（pageUrl / dialog / interceptors /     │
│   │                  lifecycle / animator / singleton）                       │
│   ├ @HMInterceptor   拦截器声明（interceptorName / priority）                 │
│   ├ @HMLifecycle     全局生命周期切片（lifecycleName）                        │
│   ├ @HMAnimator      自定义转场动画（animatorName）                           │
│   └ @HMServiceProvider 服务注册（serviceName / singleton）                    │
│                                                                              │
│  【③ HMRouterMgr 静态方法】                                                   │
│   ├ init(config)                          启动期一次性初始化                  │
│   ├ openLog(level)                        debug 日志                          │
│   ├ registerGlobalInterceptor(opts)       注册全局拦截器                      │
│   ├ push(pathInfo, callback?)             跳转                                │
│   ├ pop() / pop(pathInfo, skip?)          返回（可跳层）                      │
│   ├ replace(pathInfo)                     替换当前页                          │
│   ├ getCurrentParam()                     取路由参数                          │
│   ├ getCurrentLifecycleOwner()            拿生命周期持有者                    │
│   ├ getService<T>(serviceName)            取服务实例                          │
│   └ request(serviceName, ...args)         直接调服务方法                      │
│                                                                              │
│  【④ 枚举/接口】                                                              │
│   ├ HMLifecycleState  onShown / onHidden / onAppear / onDisAppear /          │
│   │                   onBackPressed / onWillAppear / onWillDisappear         │
│   ├ HMInterceptorAction  DO_NEXT / DO_REJECT                                 │
│   ├ HMParamType  routeParam / urlParam / ...                                 │
│   ├ IHMInterceptor   handle(info: HMInterceptorInfo) → Action                │
│   ├ IHMLifecycle     onShown / onHidden / ... hooks                          │
│   └ IHMAnimator      入场 / 出场 / 交互式转场                                 │
│                                                                              │
│  【⑤ 跨模块】                                                                 │
│   HAR / HSP 各自有 hmrouter_config.json + EntryRoutes/ChatRoutes 同名常量    │
│   编译期注解扫描必须在所属模块内，运行期 push 可跨模块                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 一、三件套：让 HMRouter 跑起来的最小代码

### 1.1 `Index.ets`：路由舞台 = HMNavigation

```typescript
// entry/src/main/ets/pages/Index.ets
import { HMNavigation } from '@hadss/hmrouter'

@Entry
@ComponentV2
export struct Index {
  build() {
    Column() {
      HMNavigation({
        navigationId: 'MainNavigation',   // ★ 全局唯一 ID
        homePageUrl: 'pages/Home',        // 启动后默认进入的页面
        options: {}
      })
    }
    .width('100%').height('100%')
  }
}
```

要点：
- `HMNavigation` 是 ArkUI 原生 `Navigation` 的封装，把"导航栈"管起来；
- `navigationId` 是**全局识别码**，后面所有 `push / replace` 都要带它（在你工程里用 `NAV_ID` 常量统一）；
- `homePageUrl` 必须是已注册的页面 url。

> 📁 项目里的 NAV_ID：[common/src/main/ets/constants/HMConstants.ets](../common/src/main/ets/constants/HMConstants.ets)
> ```typescript
> export const NAV_ID = 'MainNavigation'
> ```

### 1.2 `EntryAbility.ets`：onCreate 里启动 HMRouter

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HMRouterMgr.openLog('INFO')                // ① 打 debug 日志
    HMRouterMgr.init({ context: this.context }) // ② 必调，绑定 Ability 上下文

    // ③ 注册全局拦截器（所有 push 都会走这里）
    HMRouterMgr.registerGlobalInterceptor({
      interceptor: new SameRouteInterceptor(),
      priority: 100,
      interceptorName: 'SameRouteInterceptor'
    })
  }
  // ...
}
```

三步顺序不能错：**openLog → init → registerGlobalInterceptor**。`init` 没调任何 `push` 都不会工作。

### 1.3 `hmrouter_config.json`：告诉编译插件去哪里扫描注解

```json
// entry/hmrouter_config.json
{
  "scanDir": [
    "src/main/ets/pages",
    "src/main/ets/dialogs",
    "src/main/ets/interceptors"
  ],
  "saveGeneratedFile": true
}
```

- `scanDir`：编译插件会去这些目录下扫 `@HMRouter` / `@HMInterceptor` 等装饰器，生成静态注册代码；
- `saveGeneratedFile: true`：把生成的代码保留在 `build/hmrouter/` 下，便于调试看自动注册了什么；
- HAR 模块（如 `chat`）需要自己一份 `hmrouter_config.json`，注解扫描**不跨模块**。chat 的配置多了一项 `"autoObfuscation": true`，用于混淆兼容。

> 📁 [chat/hmrouter_config.json](../chat/hmrouter_config.json) — HAR 模块的注册配置范本

---

## 二、装饰器全集

### 2.1 `@HMRouter` — 注册页面 / Dialog / 单例

完整签名：

```typescript
@HMRouter({
  pageUrl: string,             // ★ 必填，路由 URL
  dialog?: boolean,            // 标记为对话框（半透明遮罩，非全屏）
  interceptors?: string[],     // 按 interceptorName 引用的拦截器
  lifecycle?: string,          // 引用 @HMLifecycle 注册的生命周期切片
  animator?: string,           // 引用 @HMAnimator 注册的转场动画
  singleton?: boolean          // 单例模式：重复 push 复用栈内已有实例
})
@ComponentV2
export struct XxxPage { ... }
```

项目里的四种形态：

| 形态 | 装饰器写法 | 文件 |
|---|---|---|
| 普通页面 | `@HMRouter({ pageUrl: EntryRoutes.PAGE_HOME })` | [HomePage.ets](../entry/src/main/ets/pages/HomePage.ets) |
| 受拦截器保护 | `@HMRouter({ pageUrl: ..., interceptors: ['AuthInterceptor'] })` | [CheckoutPage.ets](../entry/src/main/ets/pages/CheckoutPage.ets) |
| 对话框 | `@HMRouter({ pageUrl: ..., dialog: true })` | [LoginPromptDialog.ets](../entry/src/main/ets/dialogs/LoginPromptDialog.ets) |
| 跨模块页面 | 同上，但用各模块自己的 Routes 常量 | [ChatPage.ets](../chat/src/main/ets/pages/ChatPage.ets) |

⚠️ **编译期约束**：`pageUrl` 必须引用**同模块内的常量**。entry 里写 `EntryRoutes.PAGE_HOME` 可以，但写 `ChatRoutes.PAGE_CHAT` 会报 "Unknown variable" —— 因为装饰器是编译期静态分析，跨 HAR 解析不了。详见 [12-provider-consumer-and-har-multi-module.md](./12-provider-consumer-and-har-multi-module.md)。

### 2.2 `@HMInterceptor` — 注册拦截器

```typescript
@HMInterceptor({
  interceptorName: string,   // ★ 必填，后面 interceptors: ['XxxInterceptor'] 按名引用
  priority?: number          // 数字越大越先执行，默认 0
})
export class XxxInterceptor implements IHMInterceptor {
  handle(info: HMInterceptorInfo): HMInterceptorAction {
    // ...
    return HMInterceptorAction.DO_NEXT // 放行 / 或 DO_REJECT 拦截
  }
}
```

项目范例：

```typescript
// entry/src/main/ets/interceptors/AuthInterceptor.ets
@HMInterceptor({ interceptorName: 'AuthInterceptor', priority: 99 })
export class AuthInterceptor implements IHMInterceptor {
  handle(info: HMInterceptorInfo): HMInterceptorAction {
    if (hasToken()) return HMInterceptorAction.DO_NEXT
    HMRouterMgr.push({ pageUrl: EntryRoutes.DIALOG_LOGIN_PROMPT })  // 弹登录对话框
    return HMInterceptorAction.DO_REJECT
  }
}
```

### 2.3 `@HMLifecycle` — 全局生命周期切片

把"页面级生命周期回调"抽成可复用的类。需要时在 `@HMRouter` 的 `lifecycle` 里引用名字：

```typescript
@HMLifecycle({ lifecycleName: 'LogLifecycle' })
export class LogLifecycle implements IHMLifecycle {
  onShown(ctx: HMLifecycleContext): void {
    console.log(`[Lifecycle] ${ctx.navContext.pathInfo.name} onShown`)
  }
  onHidden(ctx: HMLifecycleContext): void {
    console.log(`[Lifecycle] ${ctx.navContext.pathInfo.name} onHidden`)
  }
}

// 引用：
@HMRouter({ pageUrl: '...', lifecycle: 'LogLifecycle' })
```

> 项目里**还没用 `@HMLifecycle`** —— 用的是 ProductDetailController 里 `addObserver` 的"页内主动注册"模式（见 §4.2）。

### 2.4 `@HMAnimator` — 自定义转场动画

```typescript
@HMAnimator({ animatorName: 'SlideAnimator' })
export class SlideAnimator implements IHMAnimator {
  effect(enterHandle: HMAnimatorHandle, exitHandle: HMAnimatorHandle): void {
    // 入场：从右侧滑入
    // 出场：向右侧滑出
    // 详见 IHMAnimator 接口
  }
}

// 引用：
@HMRouter({ pageUrl: '...', animator: 'SlideAnimator' })
```

也可以用 `HMRouterMgr.registerDefaultGlobalAnimator()` 设全局默认。`@hadss/hmrouter-transitions` 子包提供更高级的交互式转场。

> 项目里**还没自定义动画**，走的全是 HMRouter 默认转场。

### 2.5 `@HMServiceProvider` — 服务注册（跨模块调方法）

```typescript
@HMServiceProvider({ serviceName: 'UserService', singleton: true })
export class UserServiceImpl {
  getUserInfo(): UserInfo { ... }
}

// 在其他模块取用：
const svc = HMRouterMgr.getService<UserServiceImpl>('UserService')
svc.getUserInfo()

// 或者直接 request 一次性调用：
HMRouterMgr.request('UserService.getUserInfo')
```

`singleton: true` 全局只创建一次（懒加载）。常用于 chat / entry 跨 HAR 之间需要互相调方法但又不想互相 import 类的场景。

---

## 三、HMRouterMgr 静态方法详表

### 3.1 push — 跳转 + 传参

```typescript
HMRouterMgr.push({
  navigationId: string,    // 通常是 NAV_ID
  pageUrl: string,         // 目标页面 URL（必须已 @HMRouter 注册）
  param?: Object,          // 任意对象作为路由参数
  skipAllInterceptor?: boolean,  // 跳过所有拦截器（慎用）
  skipedInterceptor?: string[]   // 跳过指定拦截器
}, callback?: HMRouterPathCallback)
```

项目里的典型用法：

```typescript
// 跳转 + 传参（HomeController）
HMRouterMgr.push({
  navigationId: NAV_ID,
  pageUrl: EntryRoutes.PAGE_PRODUCT_DETAIL,
  param: product   // ★ 任意对象，目标页用 getCurrentParam() 接收
})

// 第二个参数 callback：早期项目用过 onResult 拿返回值
HMRouterMgr.push(pathInfo, { onResult: (popInfo) => { ... } })
```

### 3.2 pop — 返回

```typescript
HMRouterMgr.pop()                  // 返回上一页（最常用）
HMRouterMgr.pop(pathInfo)          // 返回时携带参数（触发上一页 callback.onResult）
HMRouterMgr.pop(undefined, 2)      // 跳过 2 层（直接回到爷爷页）
```

### 3.3 replace — 替换当前页

```typescript
HMRouterMgr.replace({
  navigationId: NAV_ID,
  pageUrl: EntryRoutes.PAGE_ORDER_LIST
})
```

栈不会增长。适合"登录成功 → 替换为首页"、"支付成功 → 替换为订单列表"这种场景。本仓库 [CheckoutController.pay](../entry/src/main/ets/controller/CheckoutController.ets) 就用 replace 把 Checkout 页替换成 OrderList。

### 3.4 getCurrentParam — 拿路由参数

```typescript
// 不带类型枚举（最常用）：拿 push 时的 param 整体
const param = HMRouterMgr.getCurrentParam()
this.vm.product = param as Product

// 带类型枚举（细分参数源）：
const routeParam = HMRouterMgr.getCurrentParam(HMParamType.routeParam) as ChatSession | null
```

⚠️ **必须在 `aboutToAppear()` 里调**，build 阶段调可能拿到 undefined。

### 3.5 getCurrentLifecycleOwner — 拿生命周期持有者

```typescript
const owner = HMRouterMgr.getCurrentLifecycleOwner()
owner?.addObserver(HMLifecycleState.onShown, () => { /* ... */ })
owner?.removeObserver(HMLifecycleState.onShown)
```

详见 §4 生命周期一节。

### 3.6 其他实用方法

| 方法 | 用途 |
|---|---|
| `HMRouterMgr.openLog(level)` | 开启日志，`'INFO' / 'DEBUG'` |
| `HMRouterMgr.init({ context })` | onCreate 必调一次 |
| `HMRouterMgr.registerGlobalInterceptor(opts)` | 注册全局拦截器（vs 装饰器的页面级拦截器） |
| `HMRouterMgr.getService<T>(name)` | 取 @HMServiceProvider 注册的服务实例 |
| `HMRouterMgr.request(name, ...args)` | 一次性调服务方法（无需持有实例） |

### 3.7 项目里的薄封装 HMUtil

[common/utils/HMUtil.ets](../common/src/main/ets/utils/HMUtil.ets) 把三个最常用方法转发了一遍：

```typescript
export class HMUtil {
  static push(pathInfo: HMRouterPathInfo, callback?: HMRouterPathCallback): void {
    HMRouterMgr.push(pathInfo, callback)
  }
  static pop(pathInfo?: HMRouterPathInfo): void { HMRouterMgr.pop(pathInfo) }
  static replace(pathInfo: HMRouterPathInfo): void { HMRouterMgr.replace(pathInfo) }
}
```

只是包一层方便后续统一切日志埋点。

---

## 四、生命周期：两种使用姿势

### 4.1 HMLifecycleState 枚举（项目里实际用到的）

| 状态 | 触发时机 | 项目里在哪用 |
|---|---|---|
| `onShown` | 页面**显示**（首次显示 / 从子页返回） | [ChatHistoryPage.ets:40](../chat/src/main/ets/pages/ChatHistoryPage.ets) 重新显示时刷新列表；[ProductDetailController.ets:49](../entry/src/main/ets/controller/ProductDetailController.ets) 演示日志 |
| `onHidden` | 页面**隐藏**（跳转到子页时） | ProductDetailController 演示日志 |
| `onAppear` | 页面**首次出现**（创建后第一次显示） | — |
| `onDisAppear` | 页面**销毁** | ProductDetailController 演示日志 |
| `onBackPressed` | 系统返回键 | — |
| `onWillAppear` / `onWillDisappear` | 出现/消失**之前** | — |

### 4.2 用法 A：页内主动注册（addObserver）

适合"我只需要这一个页面响应这个生命周期"的轻量场景：

```typescript
// entry/src/main/ets/controller/ProductDetailController.ets
initLifecycle(): void {
  const owner = HMRouterMgr.getCurrentLifecycleOwner()
  if (!owner) return

  owner.addObserver(HMLifecycleState.onShown, () => {
    this.appendLog('onShown ▶ 页面显示/从子页返回')
  })
  owner.addObserver(HMLifecycleState.onHidden, () => {
    this.appendLog('onHidden ⏸ 页面隐藏（跳转子页时）')
  })
  owner.addObserver(HMLifecycleState.onDisAppear, () => {
    this.appendLog('onDisAppear ✕ 页面销毁')
  })
}

removeLifecycle(): void {
  const owner = HMRouterMgr.getCurrentLifecycleOwner()
  owner?.removeObserver(HMLifecycleState.onShown)
  owner?.removeObserver(HMLifecycleState.onHidden)
  owner?.removeObserver(HMLifecycleState.onDisAppear)
}
```

**规范**：
- 在页面的 `aboutToAppear()` 里 `addObserver`
- 在页面的 `aboutToDisappear()` 里 `removeObserver` ← **必须移除**，否则内存泄漏

### 4.3 用法 B：全局生命周期切片（@HMLifecycle）

适合"所有页面都要打日志 / 都要做埋点"这种横切关注点：

```typescript
@HMLifecycle({ lifecycleName: 'LogLifecycle' })
export class LogLifecycle implements IHMLifecycle {
  onShown(ctx: HMLifecycleContext): void { console.log('shown') }
  onHidden(ctx: HMLifecycleContext): void { console.log('hidden') }
}

// 在页面装饰器里引用：
@HMRouter({ pageUrl: '...', lifecycle: 'LogLifecycle' })
```

项目里目前没用，但可以加在埋点 / 性能监控场景。

---

## 五、拦截器：三种作用域

### 5.1 作用域对比

| 类型 | 注册方式 | 作用范围 | 典型用途 |
|---|---|---|---|
| **全局拦截器** | `HMRouterMgr.registerGlobalInterceptor({ interceptor, priority, interceptorName })` | 所有 push 都会经过 | 防重复跳转 / 全局埋点 |
| **页面拦截器** | `@HMRouter({ interceptors: ['XxxInterceptor'] })` | 仅声明的页面 | 登录鉴权 / 灰度 / 权限校验 |
| **一次性拦截器** | `HMRouterMgr.push(pathInfo, { skipAllInterceptor: true })` 反向 | 临时跳过 | 注销跳登录页这种特殊场景 |

### 5.2 优先级（priority）

数字**越大越先执行**。项目里两个拦截器的优先级：

```text
SameRouteInterceptor  priority: 100  ← 先跑，相同路由直接拒掉
AuthInterceptor       priority: 99   ← 后跑，token 校验
```

链式执行：每一个返回 `DO_NEXT` 才进入下一个，任一返回 `DO_REJECT` 就终止。

### 5.3 SameRouteInterceptor（防重复跳转）

```typescript
// entry/src/main/ets/interceptors/SameRouteInterceptor.ets
export class SameRouteInterceptor implements IHMInterceptor {
  interceptorName: string = 'SameRouteInterceptor'
  priority: number = 100

  handle(info: HMInterceptorInfo): HMInterceptorAction {
    const fromPage = info.srcName ?? ''
    const targetPage = info.targetName ?? ''
    if (fromPage.length > 0 && targetPage.length > 0 && fromPage === targetPage) {
      return HMInterceptorAction.DO_REJECT
    }
    return HMInterceptorAction.DO_NEXT
  }
}
```

**关键字段**（`HMInterceptorInfo`）：
- `srcName`：当前页面的 url
- `targetName`：要跳转的目标页面 url
- `param`：携带参数
- `targetPageInstance`：目标页面实例（如有）

### 5.4 AuthInterceptor（登录鉴权）

```typescript
// entry/src/main/ets/interceptors/AuthInterceptor.ets
@HMInterceptor({ interceptorName: 'AuthInterceptor', priority: 99 })
export class AuthInterceptor implements IHMInterceptor {
  handle(info: HMInterceptorInfo): HMInterceptorAction {
    if (hasToken()) {
      return HMInterceptorAction.DO_NEXT
    }
    HMRouterMgr.push({ pageUrl: EntryRoutes.DIALOG_LOGIN_PROMPT })
    return HMInterceptorAction.DO_REJECT
  }
}
```

页面引用：

```typescript
@HMRouter({ pageUrl: EntryRoutes.PAGE_CHECKOUT, interceptors: ['AuthInterceptor'] })
```

**注意**：拦截器名是字符串引用，编译期不校验是否存在。打错字会运行时找不到拦截器（默默放行）。

---

## 六、Dialog：dialog: true 标志位 + 普通页面写法

```typescript
// entry/src/main/ets/dialogs/LoginPromptDialog.ets
@HMRouter({ pageUrl: EntryRoutes.DIALOG_LOGIN_PROMPT, dialog: true })
@ComponentV2
export struct LoginPromptDialog {
  build() {
    Column() {
      Column() {
        Text('请先登录').fontSize(18)
        Text('该功能需要登录后才能使用')

        Row() {
          Button('取消').onClick(() => { HMRouterMgr.pop() })
          Button('去登录').onClick(() => {
            HMRouterMgr.pop()                                       // 先关 dialog
            HMRouterMgr.push({ pageUrl: EntryRoutes.PAGE_LOGIN })   // 再去登录
          })
        }
      }
      .width('80%').backgroundColor('#FFFFFF').borderRadius(12)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#80000000')   // 半透明遮罩
  }
}
```

**Dialog 与普通页面的差异**：

| 维度 | 普通页面 | Dialog |
|---|---|---|
| 装饰器 | `dialog?: false`（默认） | `dialog: true` |
| 视觉 | 全屏 | 半透明遮罩 + 中间卡片（自己写） |
| 关闭方式 | `pop()` | `pop()` 同样写法 |
| 转场 | 推入式 | 淡入淡出 |
| 不阻塞下层 | — | 下层页面仍可见、可触摸（除非遮罩拦截）|

**Dialog 的设计原则**：
- 半透明遮罩 + 居中卡片是自己 build 的，框架不自动加
- 点遮罩区域是否关闭也是自己控制（这次没做，需要的话给最外层 Column 加 `.onClick(() => HMRouterMgr.pop())`）

---

## 七、跨模块路由（HAR / HSP）

项目里 `chat` HAR 也用 HMRouter，是跨模块路由的范本。

### 7.1 chat HAR 自己注册路由

```typescript
// chat/src/main/ets/constants/ChatRoutes.ets
export class ChatRoutes {
  static readonly PAGE_CHAT: string = 'pages/Chat'
  static readonly PAGE_CHAT_HISTORY: string = 'pages/ChatHistory'
}

// chat/src/main/ets/pages/ChatPage.ets
@HMRouter({ pageUrl: ChatRoutes.PAGE_CHAT })  // ★ 必须用本模块常量
@ComponentV2
export struct ChatPage { ... }
```

### 7.2 entry 跨模块 push 到 chat

```typescript
// entry 模块里
HMRouterMgr.push({
  navigationId: NAV_ID,
  pageUrl: EntryRoutes.PAGE_CHAT       // entry 自己定义的常量
})

// entry/src/main/ets/constants/EntryRoutes.ets
static readonly PAGE_CHAT: string = 'pages/Chat'   // ★ 字符串值要和 ChatRoutes.PAGE_CHAT 完全一致
```

### 7.3 编译期 vs 运行期

| 阶段 | 跨模块吗 | 规则 |
|---|---|---|
| 编译期（注解扫描） | ❌ 不能 | `@HMRouter({ pageUrl: X })` 里的 X 必须是同模块常量 |
| 运行期（push 调用） | ✅ 可以 | 字符串相等即可，任意模块都能 push 任意模块注册过的页面 |

这就是为什么 entry 和 chat 各自维护 `EntryRoutes` / `ChatRoutes` 但字符串值要对得上 —— 装饰器静态分析只看本模块常量，运行时路由表是字符串匹配。

详见 [12-provider-consumer-and-har-multi-module.md](./12-provider-consumer-and-har-multi-module.md) 第三节。

---

## 八、项目里所有路由的完整速查表

把所有 `@HMRouter` 注册的页面和它们的跳转关系列出来：

```text
HMNavigation(navigationId: 'MainNavigation', homePageUrl: 'pages/Home')
│
├─ pages/Home             [HomePage]
│  └─ Tabs:
│      ├─ HomeTabComp     ← @ComponentV2，不是 HMRouter 注册
│      ├─ ChatTabComp     ← 来自 chat HAR
│      └─ ProfileTabComp
│
├─ pages/Login            [LoginPage]
├─ pages/ProductDetail    [ProductDetailPage]  ← param: Product
├─ pages/Cart             [CartPage]
├─ pages/Checkout         [CheckoutPage]       ← interceptors: ['AuthInterceptor']
├─ pages/OrderList        [OrderListPage]      ← interceptors: ['AuthInterceptor']
├─ pages/FavoriteList     [FavoriteListPage]
├─ pages/Chat             [ChatPage]           ← chat HAR；param: ChatSession
├─ pages/ChatHistory      [ChatHistoryPage]    ← chat HAR；interceptors: ['AuthInterceptor']
└─ dialogs/LoginPrompt    [LoginPromptDialog]  ← dialog: true
```

跳转关系（最常用路径）：

```text
HomePage ──push(PAGE_PRODUCT_DETAIL, param=product)──> ProductDetailPage
       ──push(PAGE_CART)──> CartPage
       └ 三 Tab 切换在同一个页面内，不走 HMRouter

CartPage ──push(PAGE_CHECKOUT)──> CheckoutPage
       └ AuthInterceptor 拦截未登录 → DIALOG_LOGIN_PROMPT

CheckoutPage ──支付成功──replace(PAGE_ORDER_LIST)──> OrderListPage

ProfileTabComp ──push(PAGE_ORDER_LIST / PAGE_FAVORITE_LIST / PAGE_CHAT_HISTORY / PAGE_LOGIN)──> 对应页

LoginPromptDialog ──pop + push(PAGE_LOGIN)──> LoginPage
```

---

## 九、Q&A 速查

### Q1：`push` 和 `replace` 选哪个？

- 进入子页、可返回 → **push**
- 用新页**接替**当前页，不想回到旧页 → **replace**（登录成功 / 支付成功 / 引导页结束）

### Q2：`pop()` 怎么跳层？

```typescript
HMRouterMgr.pop()                  // 返回上一页
HMRouterMgr.pop(undefined, 2)      // 跳过 2 层（爷爷页）
HMRouterMgr.pop(pathInfo)          // 返回时把 pathInfo.param 传给上一页 callback.onResult
```

### Q3：装饰器 `interceptors: ['XX']` 和全局 `registerGlobalInterceptor` 啥时候用哪个？

| 场景 | 选哪个 |
|---|---|
| 防重复跳转、全局埋点、性能监控 | 全局 |
| 登录鉴权（少数页面要） | 装饰器 |
| 灰度开关（按页面） | 装饰器 |
| 跳转黑名单 | 全局 |

### Q4：Dialog 怎么半屏 / 自定义遮罩？

`dialog: true` 只是告诉框架"这页不是全屏页面"。**遮罩、内容卡片大小、关闭交互全是自己 build**。可以加 `.onClick(() => HMRouterMgr.pop())` 给最外层 Column 实现"点击遮罩关闭"。

### Q5：`getCurrentParam()` 何时调？

在**目标页**的 `aboutToAppear()` 里调一次。build 阶段调时机太早可能拿不到。注意类型推断 —— 用 `as XxxType` 强转：

```typescript
const param = HMRouterMgr.getCurrentParam()
this.vm.product = param as Product
```

### Q6：生命周期 `onShown` 和 `onAppear` 有什么区别？

- `onAppear`：页面**首次出现**（创建后）— 只触发一次
- `onShown`：页面**每次显示** — 从子页 pop 回来也会再次触发

**做"返回时刷新列表"用 `onShown`**（ChatHistoryPage 就是这么用的）。

### Q7：为什么 `@HMRouter({ pageUrl: ChatRoutes.PAGE_CHAT })` 在 entry 模块里报错？

编译期注解扫描只能解析同模块内的常量。跨 HAR 引用编译插件不认识，需要：
- 在 entry 模块自己定义同名字符串常量（`EntryRoutes.PAGE_CHAT = 'pages/Chat'`）
- 然后 `HMRouterMgr.push({ pageUrl: EntryRoutes.PAGE_CHAT })`

详见 [12 篇](./12-provider-consumer-and-har-multi-module.md)。

### Q8：拦截器名字打错了怎么办？

字符串引用，**编译期不检查**。打错字会运行时找不到拦截器，**默默放行**。Code review 时是高频低级 bug，建议把拦截器名抽常量：

```typescript
class Interceptors {
  static readonly AUTH = 'AuthInterceptor'
  static readonly SAME_ROUTE = 'SameRouteInterceptor'
}

@HMRouter({ pageUrl: '...', interceptors: [Interceptors.AUTH] })
```

### Q9：转场动画怎么改？

三个层级：
1. **全局默认**：`HMRouterMgr.registerDefaultGlobalAnimator(...)`
2. **页面级**：`@HMRouter({ pageUrl: '...', animator: 'SlideAnimator' })` + `@HMAnimator` 注册
3. **单次跳转级**：`push` 时传入 animator 配置

项目目前用的全是 HMRouter 默认转场。

### Q10：`HMRouterMgr.init()` 不调会怎样？

所有 `push / pop / replace` 都不会工作（路由框架未初始化）。务必在 `EntryAbility.onCreate()` 调一次。

---

## 十、官方文档链接

| 资源 | 链接 |
|---|---|
| HMRouter 主仓库（gitee） | https://gitee.com/hadss/hmrouter |
| HMRouter 高级转场子包 | https://gitee.com/hadss/hmrouter-transitions |
| 鸿蒙原生导航 Navigation | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navigation |
| 鸿蒙文档中心总入口 | https://developer.huawei.com/consumer/cn/doc/ |

---

## 十一、给将来的自己：HMRouter 三条铁律

1. **`@HMRouter` 的 `pageUrl` 必须用同模块常量**——跨模块路由靠"字符串值对得上"，不靠 import；
2. **`getCurrentParam()` 一定在 `aboutToAppear()` 里调**——build 阶段调可能为 undefined；
3. **生命周期 `addObserver` 必须配对 `removeObserver`**——前者在 `aboutToAppear`，后者在 `aboutToDisappear`，否则内存泄漏；

记住这三条，HMRouter 工程里 95% 的诡异问题都能避免。
