# 鸿蒙练习 12：Provider/Consumer 跨层共享 + HAR 多模块拆分

> 一个 demo 项目从单模块演化成多模块（entry + common HAR + chat HAR）的完整过程。同时落地 V2 状态管理的 `@Provider`/`@Consumer` 跨层共享。本文目标：以后自己拆模块或者用 Provider 时回来翻就能照做。

---

## 一、本次分支

```bash
feature/provider-and-multi-module
```

提交记录涉及 60+ 文件变动（新增 488 行 / 删除 906 行——大部分删除来自把代码搬到新 HAR）。

## 二、本次目标

1. 用 `@Provider`/`@Consumer` 把分散在多个组件里的 `getAuthPersist()` 调用统一成"上面提供、下面消费"的响应式订阅
2. 把单个 entry 模块拆成 entry + common + chat 三个模块，体验真实多模块开发与跨 HAR 路由

---

## 三、第一部分：@Provider / @Consumer 跨层共享

### 3.1 解决的问题

改造前，多个组件都直接调全局函数拿登录状态：

```typescript
// ProfileTabComp.ets 改造前
import { getAuthPersist } from '../utils/AuthPersist'

@ComponentV2
struct ProfileTabComp {
  build() {
    Text(getAuthPersist().userName || '用户')   // 调一次函数
    if (getAuthPersist().token.length > 0) {     // 又调一次
      Button('退出登录')
    } else {
      Button('去登录')
    }
  }
}

// HomeTabComp.ets 想加欢迎语？得自己再 import getAuthPersist
// LoginPage.ets 同样
// ...每个组件都是一份隐式的全局依赖
```

问题：
- **隐式依赖**：组件外面看不出它依赖谁，必须看 build 函数才知道
- **难测试**：单元测试时没法 mock 一个假的 auth
- **难复用**：组件锁死在"全局只有一个 auth"的假设里

### 3.2 改造方案

让位于 Tab 容器顶层的 `HomePage` 作为 Provider 提供 auth，所有子 Tab 组件作为 Consumer 消费：

```
HomePage (@Provider auth)
  ├─ HomeTabComp     (@Consumer auth) ← 新增欢迎语
  ├─ ChatTabComp
  └─ ProfileTabComp  (@Consumer auth)
```

### 3.3 关键代码

**HomePage.ets 顶部提供**：

```typescript
@HMRouter({ pageUrl: EntryRoutes.PAGE_HOME })
@ComponentV2
export struct HomePage {
  @Local tabState: AppTabState = AppStorageV2.connect(...)

  // ↓ 关键一行：作为整个 Tab 树的状态源头
  @Provider() auth: AuthPersist = getAuthPersist()

  @Local bottomAvoid: number = WindowUtil.getBottomAvoidHeight()
  // ...
}
```

**HomeTabComp.ets 消费 + 新增欢迎语**：

```typescript
@ComponentV2
export struct HomeTabComp {
  @Consumer() auth: AuthPersist = new AuthPersist()   // 默认值兜底

  build() {
    Row() {
      Column({ space: 2 }) {
        // 登录与否，欢迎语自动切换
        Text(this.auth.userName ? `你好，${this.auth.userName}` : '你好，游客')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Text('欢迎来到精选课程').fontSize(12).fontColor('#888888')
      }
      // ...
    }
  }
}
```

**ProfileTabComp.ets 替换 4 处 getAuthPersist()**：

```typescript
@ComponentV2
export struct ProfileTabComp {
  @Consumer() auth: AuthPersist = new AuthPersist()

  build() {
    Text(this.auth.userName?.charAt(0).toUpperCase() ?? 'U')   // 替换 1
    Text(this.auth.userName || '用户')                          // 替换 2
    if (this.auth.token.length > 0) {                           // 替换 3
      Button('退出登录').onClick(() => this.logout())
    } else {
      Button('去登录').onClick(() => /* push 登录页 */)         // 替换 4
    }
  }
}
```

### 3.4 数据流变化

改造前：每个组件 → 全局 `getAuthPersist()` → 单例对象

```
ProfileTabComp ───┐
HomeTabComp ──────┼──→ getAuthPersist() ──→ AuthPersist 单例
LoginPage ────────┘
```

改造后：状态从上往下流动

```
HomePage (Provider 持有 AuthPersist 实例)
   │
   ├──→ HomeTabComp.@Consumer → 拿到引用，订阅 token/userName 变化
   │
   ├──→ ChatTabComp
   │
   └──→ ProfileTabComp.@Consumer → 同上
```

### 3.5 三个验收点理解

**Q1：`@Consumer() auth: AuthPersist = new AuthPersist()` 默认值什么时候用？**

只有当 Consumer 组件被放在**没有匹配 Provider 的组件树**里时才会用——比如有人把 ProfileTabComp 拿到另一个根页面用，那里没有 @Provider auth，就会用 `new AuthPersist()` 兜底，不至于运行时崩溃。

正常使用下，ArkUI 初始化 Consumer 时会向上找匹配的 Provider，找到就直接用 Provider 的引用，默认值对象会被丢弃。

**Q2：`saveAuth()` 修改的是 `PersistenceV2` 单例，没经过 Provider，为什么所有 Consumer 都刷新？**

关键拆成两件事：

```
数据共享靠单例：
  PersistenceV2.connect(AuthPersist, 'auth_persist', ...) 
  同一个 key 第二次调用返回首次创建的实例
  → 所有访问点（getAuthPersist()、@Provider、@Consumer、saveAuth 内部）拿到的都是【同一个内存对象】

变化通知靠 @Trace：
  @ObservedV2 + @Trace 在字段 setter 上拦截
  → 通知所有访问过这个字段的 build 函数重新执行
```

**Provider/Consumer 本身不负责通知，只负责"传递引用"**。通知是 `@Trace` 干的。所以 Controller/Interceptor 这种非组件也能改这个对象，UI 一样会刷新。

**Q3：直接用 `getAuthPersist().userName` 行不行？跟 Provider 比有什么区别？**

| | `getAuthPersist()` 直接调用 | `@Consumer` 注入 |
|---|---|---|
| 依赖关系 | 隐式（藏在 build 里） | 显式（声明在组件字段上） |
| 可测试性 | 难，没法 mock 全局函数 | Provider 可注入假数据 |
| 可复用性 | 锁死全局单例 | 不同 Provider 可注入不同 auth |
| 性能 | 每次都查 PersistenceV2 单例表 | 一次绑定引用，后续直接访问 |

**真正能区分两者的场景**：账号切换。如果想"左半屏显示账号 A，右半屏显示账号 B"，用 Provider 只需各自包一层 Provider 提供不同 auth，组件不动；用 `getAuthPersist()` 永远只能拿全局那一份，需求做不了。

---

## 四、第二部分：HAR 多模块拆分

### 4.1 解决的问题

单 entry 模块下，所有页面/组件/工具堆在一起，问题：
- 业务边界混乱，谁能用谁全靠自觉
- 没法独立按需加载（一切都打进主包）
- 复用代码到其他项目时，只能整个目录 copy

公司的真实鸿蒙项目都是多 HAR/HSP 架构，这次在 demo 里走完整流程，理解每一步在做什么。

### 4.2 拆分前 vs 拆分后

**拆分前**（单 entry）：

```
entry/                       ← HAP 主包
└── src/main/ets/
    ├── pages/
    │   ├── HomePage.ets
    │   ├── LoginPage.ets
    │   ├── ChatPage.ets        ← 聊天
    │   ├── ChatHistoryPage.ets ← 聊天
    │   └── ProductDetailPage.ets
    ├── components/
    │   ├── HomeTabComp.ets
    │   ├── ProfileTabComp.ets
    │   ├── ChatTabComp.ets     ← 聊天
    │   ├── ChatListComp.ets    ← 聊天
    │   └── ChatInputComp.ets   ← 聊天
    ├── utils/         ← 全部塞这里
    ├── constants/     ← 全部塞这里
    └── models/        ← 全部塞这里
```

**拆分后**（entry + common + chat）：

```
MyApplication/
├── common/                  ← HAR：公共工具
│   ├── Index.ets            (export 6 个共享 API)
│   ├── oh-package.json5     (无依赖，叶子节点)
│   └── src/main/ets/
│       ├── utils/           (HMUtil, HttpUtil, WindowUtil)
│       ├── constants/       (HMConstants, ApiConstants)
│       └── models/          (commonModel · ApiResponse)
│
├── chat/                    ← HAR：聊天业务模块
│   ├── Index.ets            (export ChatTabComp, ChatRoutes)
│   ├── hmrouter_config.json (扫描自己的 pages)
│   ├── oh-package.json5     (依赖 common)
│   └── src/main/ets/
│       ├── pages/           (ChatPage, ChatHistoryPage)
│       ├── components/      (ChatTabComp, ChatListComp, ChatInputComp)
│       ├── constants/       (ChatRoutes)
│       ├── controller/      (ChatController)
│       ├── viewmodel/       (ChatViewModel)
│       ├── biz/             (ChatBiz)
│       ├── imp/             (ChatImp)
│       ├── models/          (chatModel)
│       └── utils/           (ChatPersist)
│
└── entry/                   ← HAP 主包
    ├── oh-package.json5     (依赖 common + chat)
    └── src/main/ets/        (剩下的页面、auth 相关、入口)
```

### 4.3 鸿蒙的三种包类型回顾

| 类型 | 全称 | 编译/加载 | 是否独立运行 |
|------|------|----------|------------|
| **HAP** | HarmonyOS Ability Package | 主包，安装时下载 | 是 |
| **HAR** | HarmonyOS Archive | 静态库，**编译时打进 HAP** | 否，作为依赖 |
| **HSP** | HarmonyOS Shared Package | 动态共享包，**运行时按需下载** | 否，作为依赖 |

本次拆的是 HAR，不是 HSP。HAR 在编译时被 entry 整个吸收进 hap 文件，不影响首包大小。如果想真正按需加载，需要换成 HSP。HAR 拆分的主要价值是**代码组织 + 复用**，HSP 的价值才是**首包减负**。

### 4.4 拆分要解决的四个核心机制

整个拆分本质做了两件事：**分离**（搬文件）和**链接**（让模块找到彼此）。难点全在链接，靠四个机制配合。

#### 机制 1：依赖声明（`oh-package.json5`）

声明"我能用谁"。

```json
// chat/oh-package.json5
{
  "name": "chat",
  "main": "Index.ets",
  "dependencies": {
    "common": "file:../common"
  }
}

// entry/oh-package.json5
{
  "name": "entry",
  "dependencies": {
    "common": "file:../common",
    "chat":   "file:../chat"
  }
}

// common/oh-package.json5 不声明任何依赖（叶子节点）
```

依赖图必须是单向的有向无环图：

```
entry  ← HAP，可以依赖任何 HAR
 ├─ chat
 │   └─ common
 └─ common
```

**重要约束**：HAR 不能依赖 HAP，只能 HAP 依赖 HAR。所以 chat 里**不能 import entry 的东西**（这就是为什么 AuthInterceptor 还留在 entry——chat 反向用不到）。

#### 机制 2：对外暴露（`Index.ets`）

声明"别人能看到我什么"。

```typescript
// chat/Index.ets
export { ChatTabComp } from './src/main/ets/components/ChatTabComp'
export { ChatRoutes } from './src/main/ets/constants/ChatRoutes'

// 内部的 ChatController、ChatBiz、ChatPersist 不 export
// → 外人即使知道它们存在也用不到，是"私有"的
```

`Index.ets` 是 HAR 的对外接口，由 `oh-package.json5` 的 `main` 字段指定，默认就叫 `Index.ets`。这是 HAR 的封装边界——内部怎么改，只要 export 出去的 API 不变，使用方感知不到。

#### 机制 3：import 路径变化

```typescript
// 同模块内：相对路径
import { ChatViewModel } from '../viewmodel/ChatViewModel'

// 跨模块：用模块名（就是 oh-package.json5 里的 name）
import { ChatTabComp } from 'chat'         // 不是 './chat'，直接 'chat'
import { HMUtil } from 'common'
```

写 `from 'chat'` 时，DevEco 在 entry/oh-package 的 dependencies 里找 `chat` → 找到本地路径 → 去 `chat/Index.ets` 拿 export 出来的东西。

**所以"声明依赖 + Index.ets export"两件事缺一不可**：少了依赖，IDE 找不到模块；少了 export，IDE 找得到模块但拿不到具体的类。

#### 机制 4：每个 HAR 自己的 `hmrouter_config.json`

HMRouter 是分散注册、运行时合并：

```json
// entry/hmrouter_config.json
{
  "scanDir": [
    "src/main/ets/pages",
    "src/main/ets/dialogs",
    "src/main/ets/interceptors"
  ],
  "autoObfuscation": true
}

// chat/hmrouter_config.json
{
  "scanDir": [
    "src/main/ets/pages",
    "src/main/ets/dialogs",
    "src/main/ets/interceptors"
  ],
  "autoObfuscation": true
}
```

每个 HAR 自己有一份配置，扫描自己的 `pages` 目录。编译时各自生成自己的路由注册代码；运行时 entry 加载 → 注册 entry 路由表，chat 加载 → 注册 chat 路由表，**两份注册合并到同一个全局路由表**。

### 4.5 真正踩到的两个生产坑

#### 坑 1：装饰器不能用跨 HAR 常量

第一次重构时把 `route` 常量放到了 common HAR，结果编译报错：

```
hvigor ERROR: [HMRouterPlugin][]: error code: 40000304, 
error message: Unknown variable: route undefined
```

**原因**：HMRouter 的 `@HMRouter` 装饰器是**编译期静态分析**——插件只能解析**同模块内**的常量值，跨 HAR 的常量它解析不到。

**修复方案**：每个 HAR 定义自己的路由常量类，装饰器用本模块的：

```typescript
// entry/src/main/ets/constants/EntryRoutes.ets
export class EntryRoutes {
  static readonly PAGE_HOME: string = 'pages/Home'
  static readonly PAGE_LOGIN: string = 'pages/Login'
  // ...
}

// chat/src/main/ets/constants/ChatRoutes.ets
export class ChatRoutes {
  static readonly PAGE_CHAT: string = 'pages/Chat'
  static readonly PAGE_CHAT_HISTORY: string = 'pages/ChatHistory'
}

// HomePage.ets（entry 模块）
@HMRouter({ pageUrl: EntryRoutes.PAGE_HOME })   // ← 同模块常量，能解析

// ChatPage.ets（chat 模块）
@HMRouter({ pageUrl: ChatRoutes.PAGE_CHAT })    // ← 同模块常量，能解析
```

但**运行时调用**没这个限制，跨模块拿常量随便：

```typescript
// entry 里跨模块跳 chat 的页面
HMRouterMgr.push({ pageUrl: 'pages/ChatHistory' })           // 字符串字面量 OK
// 或者
import { ChatRoutes } from 'chat'
HMRouterMgr.push({ pageUrl: ChatRoutes.PAGE_CHAT_HISTORY })  // 跨模块常量 OK
```

**规律**：装饰器参数走编译期静态分析，必须用同模块常量；运行时调用是动态执行，怎么写都行。

#### 坑 2：循环依赖与公共类型的归属

第一版改造把 `ApiResponse` 留在了 `entry/models/chatModel.ets`，结果 `HttpUtil`（要搬到 common）和 `AuthImp`（留在 entry）都依赖 `ApiResponse`——形成了 common → entry/chatModel 的反向依赖，违反"HAR 不能依赖 HAP"。

**修复**：把通用类型（`ApiResponse`）单独拆到 common 的 `commonModel.ets`，专门给被依赖方使用：

```typescript
// common/src/main/ets/models/commonModel.ets
export class ApiResponse<T> {
  code: number = 0
  message: string = ''
  data: T | null = null
}

// chat/src/main/ets/models/chatModel.ets
export class ChatMessage { ... }   // 只放 chat 特有的
export class ChatSession { ... }
// ApiResponse 已迁移到 common（不再定义）

// entry 和 chat 都从 common 引：
import { ApiResponse } from 'common'
```

**规律**：被多模块共用的类型一定要放在依赖链最深的那个模块（叶子节点）。

### 4.6 跨模块路由的运行时如何透明工作

一个完整跳转，跨了三个模块但调用方完全感知不到：

```
用户操作：未登录用户点 Profile Tab → 消息记录

[entry 模块]
1. ProfileTabComp.onClick:
   HMRouterMgr.push({ navigationId: NAV_ID, pageUrl: 'pages/ChatHistory' })
                              ↑ 来自 common         ↑ 字符串字面量

2. HMRouter 查全局路由表
   'pages/ChatHistory' → chat HAR 的 ChatHistoryPage 类
   
3. 检查目标的 @HMRouter 装饰器有 interceptors: ['AuthInterceptor']
   按字符串名查全局拦截器表 → entry 里注册的 AuthInterceptor

[entry 模块]
4. AuthInterceptor.handle():
   hasToken() 返回 false（读 entry 里的 AuthPersist）
   HMRouterMgr.push({ pageUrl: 'dialogs/LoginPrompt' })
   返回 DO_REJECT

5. HMRouter 查 'dialogs/LoginPrompt'
   → entry 的 LoginPromptDialog 类 → 渲染弹窗

(用户点"去登录" → 登录成功 → 再点消息记录)

[entry → chat 模块]
6. 同样的 push('pages/ChatHistory')
   → 拦截器放行 → 跨模块进入 chat HAR 的 ChatHistoryPage
   → 列表 onShown 触发 loadData
```

整个过程**调用方只看到字符串**——这就是"模块解耦"的真正含义。HMRouter 用"字符串 + 运行时全局表"这个简单设计，绕开了静态依赖的所有束缚。

### 4.7 操作清单总览

| 操作 | 对应机制 |
|------|---------|
| 在 DevEco Studio `File → New → Module` 创建 Static Library | 创建 HAR |
| 编辑 `oh-package.json5` 的 `dependencies` 加 `"common": "file:../common"` | 机制 1 |
| 编辑 `Index.ets` 决定导出哪些类/函数 | 机制 2 |
| 代码里 `import { X } from 'common'` 跨模块引用 | 机制 3 |
| 每个 HAR 根目录建 `hmrouter_config.json` 配 scanDir | 机制 4 |
| 装饰器参数用同模块的 `XxxRoutes.PAGE_XXX` 常量类 | 坑 1 修复 |
| 共享类型放进依赖链最深的模块（叶子） | 坑 2 修复 |
| 运行时 `HMRouterMgr.push({ pageUrl })` 用字符串字面量或任意模块的常量 | 跨模块跳转 |

---

## 五、总结：一句话理解

- **`@Provider/@Consumer`**：解决"组件如何拿到上下文里的状态"——是 React Context 那一类的工具。响应式通知靠 `@ObservedV2 + @Trace`，Provider 只负责"传引用"。
- **HAR 多模块拆分**：本质是用 `oh-package.json5` 声明依赖 + `Index.ets` 公开 API + 模块名 import，把"一堆文件互相 import"重组成"多个明确边界的包"。HMRouter 通过"每个模块独立注册到运行时全局表"让跨模块跳转看起来跟同模块一样。

回到本文最初的"以后能不能照做"问题：

```
拆模块需要做什么？
  → 在 DevEco 建模块（GUI 操作）
  → oh-package.json5 声明依赖
  → Index.ets 决定对外暴露
  → 移文件、改 import
  → 装饰器场景注意"同模块常量"约束

Provider 用在哪？
  → 多个组件需要订阅同一个状态，但不想到处 import 全局函数
  → 把 @Provider 放在它们的公共祖先
  → 子组件用 @Consumer 拿到响应式引用
```

---

## 六、参考文档

- [@Provider 装饰器和 @Consumer 装饰器：跨组件层级双向同步](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-provider-and-consumer)
- [状态管理（V2）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-state-management-v2)
- [V1-V2 迁移概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-v1-v2-migration)
- [HAR 静态共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/har-package)
- [HSP 动态共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/in-app-hsp)
- [oh-package.json5 配置说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ohpm-package)
- [HMRouter Gitee 仓库](https://gitee.com/hadss/hmrouter)
- [HMRouter Reference 文档](https://gitee.com/hadss/hmrouter/blob/master/docs/Reference.md)
