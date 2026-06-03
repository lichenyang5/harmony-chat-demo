# 鸿蒙聊天 Demo 练习 11：路由拦截器 + dialog 路由 + 页面生命周期

## 一、本次分支

```bash
feature/auth-guard
```

## 二、本次目标

把已有的"必须登录才能用"流程改造成游客模式，并加入三个 HMRouter 进阶能力：

1. **AuthInterceptor 路由拦截器** —— 未登录访问受保护页面时拦截
2. **LoginPromptDialog dialog 路由** —— 不是普通弹窗，而是走路由栈的"弹窗页面"
3. **onShown 页面生命周期** —— 从下层 pop 回来时刷新列表

整体串成一个真实场景：

```
启动 → 直接进 Home（游客模式）
  ↓
切到 Profile Tab → 看到"去登录"按钮
  ↓
点"消息记录"菜单
  ↓ AuthInterceptor 拦截 PAGE_CHAT_HISTORY
未登录 → push LoginPromptDialog
  ↓ 用户点"去登录"
push LoginPage → 登录成功 pop 回 Profile
  ↓
再点"消息记录" → 通过 → 进入 ChatHistoryPage（onShown 触发首次加载）
  ↓ 点某条会话
push ChatPage → 聊几句 → pop 回 ChatHistoryPage
  ↓ onShown 再次触发 → 列表刷新看到新会话
```

## 三、为什么要做这件事

之前 demo 的流程有个不真实的地方：**首页就是登录页**，必须登录才能看到 Tab 容器。但现实里大多数 App（淘宝、知乎、B站）允许游客浏览，只有触发关键操作（评论、下单、看个人中心隐私）才登录。

要实现游客模式，绕不开三个能力：
- 路由层面的"权限守卫"——拦截器
- 友好的登录引导——弹窗
- 状态变化后的数据同步——生命周期

正好是 HMRouter 的三个核心能力。

## 四、关键改造点

### 4.1 配置：让 HMRouter 扫描更多目录

**文件**：`entry/hmrouter_config.json`

```json
{
  "scanDir": [
    "src/main/ets/pages",
    "src/main/ets/dialogs",
    "src/main/ets/interceptors"
  ],
  "saveGeneratedFile": true
}
```

HMRouter 的 Hvigor 插件只扫描 `scanDir` 列出的目录，里面带 `@HMRouter` 或 `@HMInterceptor` 装饰器的类才会被生成注册代码。

**踩坑**：改完这个文件**必须 Rebuild Project**，否则新加的拦截器和 dialog 不会被注册。

### 4.2 入口改造：Login 不再是首页

**文件**：`entry/src/main/ets/pages/Index.ets`

```typescript
HMNavigation({
  navigationId: 'MainNavigation',
  homePageUrl: 'pages/Home',   // ← 原来是 'pages/Login'
  options: {}
})
```

连锁修改：
- `LoginPage.aboutToAppear`：已登录从 `replace(Home)` 改成 `pop()`（已不是入口，回到上一页即可）
- `AuthController.login` 成功：从 `replace(Home)` 改成 `pop()`（保留路由栈）
- `ProfileTabComp.logout`：删掉 `replace(Login)`，退出后留在 Profile，UI 自动变成"去登录"按钮

### 4.3 dialog 路由：长得像弹窗的页面

**新建文件**：`entry/src/main/ets/dialogs/LoginPromptDialog.ets`

```typescript
import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { route } from '../constants/HMConstants'

@HMRouter({ pageUrl: route.DIALOG_LOGIN_PROMPT, dialog: true })
@ComponentV2
export struct LoginPromptDialog {

  build() {
    Column() {
      Column() {
        Text('请先登录').fontSize(18).fontWeight(FontWeight.Medium)
        Text('该功能需要登录后才能使用').fontSize(14).fontColor('#666666')

        Row() {
          Button('取消').onClick(() => { HMRouterMgr.pop() })
          Button('去登录').onClick(() => {
            HMRouterMgr.pop()                                     // 先关 dialog
            HMRouterMgr.push({ pageUrl: route.PAGE_LOGIN })       // 再去登录页
          })
        }
      }
      .width('80%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#80000000')   // 半透明黑色遮罩
  }
}
```

**核心**：`dialog: true` 让 HMRouter 把这个组件作为"路由栈的一员"，可以 `push`/`pop`。

### 4.4 拦截器：装饰器风格的路由守卫

**新建文件**：`entry/src/main/ets/interceptors/AuthInterceptor.ets`

```typescript
import {
  HMInterceptor, HMInterceptorAction, HMInterceptorInfo,
  HMRouterMgr, IHMInterceptor
} from '@hadss/hmrouter'
import { hasToken } from '../utils/AuthPersist'
import { route } from '../constants/HMConstants'

@HMInterceptor({ interceptorName: 'AuthInterceptor', priority: 99 })
export class AuthInterceptor implements IHMInterceptor {

  handle(info: HMInterceptorInfo): HMInterceptorAction {
    if (hasToken()) {
      return HMInterceptorAction.DO_NEXT     // 已登录，放行
    }
    HMRouterMgr.push({ pageUrl: route.DIALOG_LOGIN_PROMPT })
    return HMInterceptorAction.DO_REJECT     // 未登录，拦截原跳转
  }
}
```

**绑定到 ChatHistoryPage**：

```typescript
@HMRouter({
  pageUrl: route.PAGE_CHAT_HISTORY,
  interceptors: ['AuthInterceptor']   // ← 通过 interceptorName 字符串引用
})
@ComponentV2
export struct ChatHistoryPage { ... }
```

### 4.5 onShown 生命周期：从下层 pop 回来时刷新

**改造文件**：`entry/src/main/ets/pages/ChatHistoryPage.ets`

```typescript
import { HMRouter, HMRouterMgr, HMLifecycleState } from '@hadss/hmrouter'

aboutToAppear(): void {
  this.ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
  this.loadData()

  // 注册 onShown：每次成为路由栈顶都触发（包括从 ChatPage pop 回来）
  HMRouterMgr.getCurrentLifecycleOwner()?.addObserver(
    HMLifecycleState.onShown,
    () => {
      console.log('[ChatHistoryPage] onShown 触发，刷新列表')
      this.loadData()
    }
  )
}
```

## 五、几个关键概念辨析

### 5.1 装饰器拦截器 vs 全局拦截器

| | `@HMInterceptor` 装饰器 | `registerGlobalInterceptor` 全局 |
|---|---|---|
| 触发范围 | 只在 `interceptors` 数组里声明的页面触发 | 所有路由跳转都触发 |
| 是否需要白名单 | 不需要 | 需要，否则会拦死自己 |
| 代码位置 | 哪些页面需要登录，在那个页面声明 | 拦截规则集中在一个文件里 |
| 适用场景 | 局部规则（登录、VIP、地区限制） | 全局规则（埋点、网络状态、防重复跳转） |

判断依据：**规则适用页面 ≥ 80% 用全局；< 20% 用装饰器。**

demo 里现存的 `SameRouteInterceptor` 是全局的（"防重复跳转"对所有页面都适用），新加的 `AuthInterceptor` 是装饰器的（只有少数页面要登录）。

### 5.2 dialog 路由 vs CustomDialog

| | CustomDialog | dialog 路由 |
|---|---|---|
| 是否在路由栈 | ❌ 不在 | ✅ 在 |
| 打开方式 | `controller.open()` | `HMRouterMgr.push()` |
| 拦截器 | ❌ 不支持 | ✅ 支持 |
| 跳转其他页面 | 需要外部协调 | 直接 `push`，路由栈自然处理 |
| 跨模块打开 | ❌ 困难 | ✅ 用字符串 pageUrl 直接打开 |

**判断依据**：只要弹窗需要跟路由系统打交道（push 其他页面、被拦截器触发、跨模块、传参），就用 dialog 路由；纯展示性的简单提示用 CustomDialog 即可。

本次场景里：拦截器在路由层面，要打开弹窗只能用 `HMRouterMgr.push`，CustomDialog 没有合适的 controller 实例可拿——所以必然用 dialog 路由。

### 5.3 onShown vs aboutToAppear

| 钩子 | 触发时机 | 触发次数 | 类比 |
|---|---|---|---|
| `aboutToAppear` | 组件**实例**被创建时 | 一辈子一次 | 出生 |
| `aboutToDisappear` | 组件实例被销毁时 | 一辈子一次 | 死亡 |
| `onShown` | 页面变成路由栈顶时 | 多次 | 上台 |
| `onHidden` | 页面被压到下层时 | 多次 | 下台 |

完整路径示意（ChatHistoryPage 视角）：

```
事件                      aboutToAppear  onShown  aboutToDisappear  onHidden
─────────────────────────────────────────────────────────────────────────────
push ChatHistoryPage       ✅            ✅        ❌                ❌
push ChatPage 压在上面     ❌            ❌        ❌                ✅
pop ChatPage 回到 History  ❌            ✅        ❌                ❌
pop ChatHistoryPage 自己   ❌            ❌        ✅                ✅
```

**为什么必须用 onShown**：
- 用户从 ChatHistory 点会话 → push ChatPage 聊天 → ChatPage 把新会话写入存储
- pop 回 ChatHistory 时，实例没销毁，`aboutToAppear` 不会再触发
- 如果只在 `aboutToAppear` 里 `loadData()`，列表永远停留在进入时的快照
- 必须在 `onShown` 里也调 `loadData()`，列表才能刷新看到新数据

## 六、一句话总结

> 拦截器解决"该不该跳"，dialog 路由解决"用什么形式提示用户"，onShown 解决"跳完之后数据怎么更新"。三个能力串起来，才能让游客模式真正可用。

## 七、参考

- [HMRouter Reference](https://gitee.com/hadss/hmrouter/blob/master/docs/Reference.md)
- [@HMInterceptor 装饰器](https://gitee.com/hadss/hmrouter/blob/master/docs/Reference.md#hminterceptor)
- 本次提交：`d5abb84` 路由弹窗添加，拦截器，以及一些基础概念文档
