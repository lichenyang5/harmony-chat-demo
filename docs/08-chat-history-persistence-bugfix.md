# 鸿蒙实战：聊天记录持久化 · 历史会话页面 · 两个真实 Bug 的定位与修复

> 本篇记录从零到一实现「聊天历史记录」功能的全过程，以及开发中踩到的两个真实 Bug：  
> **点击历史记录后页面空白** 和 **Tab Bar 随键盘弹起**。  
> 代码路径均在 `entry/src/main/ets/` 下。

---

## 一、功能概览

本次迭代新增/修改了以下内容：

| 文件 | 类型 | 作用 |
|---|---|---|
| `models/chatModel.ets` | 修改 | 新增 `ChatSession` 数据模型 |
| `utils/ChatPersist.ets` | 新增 | 基于 `Preferences` 的会话持久化工具 |
| `pages/ChatHistoryPage.ets` | 新增 | 历史会话列表页（支持左滑删除） |
| `components/ChatTabComp.ets` | 修改 | 对话结束后自动保存会话 + 修复键盘 Bug |
| `pages/ChatPage.ets` | 修改 | 修复打开历史记录后页面空白的 Bug |
| `components/ProfileTabComp.ets` | 修改 | 「我的」页面菜单项绑定跳转 |
| `constants/HMConstants.ets` | 修改 | 新增 `PAGE_CHAT_HISTORY` 路由常量 |

---

## 二、数据模型设计

### 2.1 ChatSession

聊天历史的核心是会话（Session）的概念：一次完整的对话是一个 Session，包含多条消息。

```typescript
// models/chatModel.ets
export class ChatSession {
  id: string = ''           // 会话唯一 ID（时间戳字符串，天然唯一）
  title: string = ''        // 标题：取第一条用户消息前 20 字
  preview: string = ''      // 列表预览文案：最后一条消息前 30 字
  createTime: number = 0    // 创建时间（ms 时间戳）
  updateTime: number = 0    // 最后更新时间（ms 时间戳）
  messages: ChatMessage[] = []
}
```

**设计思路：**
- `id` 用时间戳字符串，不依赖 UUID 库，也不需要服务端分配
- `title` 和 `preview` 是冗余字段，专门给列表页展示用，避免每次渲染都遍历 `messages`
- `updateTime` 用于列表排序（最近使用的排在前面）

### 2.2 会话 ID 生成时机

```typescript
// components/ChatTabComp.ets
aboutToAppear(): void {
  // 每次进入 Tab 生成新会话 ID（时间戳，天然唯一）
  this.vm.sessionId = Date.now().toString()
  // ...
}
```

为什么在 `aboutToAppear` 而不是组件初始化时生成？  
因为 `ChatTabComp` 在整个 App 生命周期内只实例化一次（Tabs 不销毁子组件），每次切换到 AI 助手 Tab 都应该开启新会话，所以需要在每次「进入」时重新生成。

---

## 三、持久化工具：ChatPersist

### 3.1 存储方案选择

| 方案 | 适用场景 | 本项目 |
|---|---|---|
| `AppStorage / AppStorageV2` | 内存级，App 重启后消失 | ❌ 不满足持久化 |
| `PersistenceV2` | 自动持久化单个类实例 | 适合少量全局状态（如登录信息） |
| `@kit.ArkData.preferences` | KV 文件存储，支持复杂结构 | ✅ 聊天记录 |
| 关系数据库（relationalStore） | 结构化查询，大数据量 | 过重 |

聊天记录是「列表 + 嵌套数组」的结构，用 `Preferences` 以 JSON 序列化整个数组即可，简单直接。

### 3.2 核心实现

```typescript
// utils/ChatPersist.ets
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { ChatSession } from '../models/chatModel'

const STORE_NAME = 'chat_history'
const KEY_SESSIONS = 'sessions'

// 加载所有会话（按 updateTime 降序，最近的在前）
export function loadSessions(ctx: common.UIAbilityContext): ChatSession[] {
  try {
    const store = preferences.getPreferencesSync(ctx, { name: STORE_NAME })
    const raw = store.getSync(KEY_SESSIONS, '[]') as string
    const arr = JSON.parse(raw) as ChatSession[]
    return arr.sort((a, b) => b.updateTime - a.updateTime)
  } catch (_) {
    return []
  }
}

// 保存（upsert：有则更新，无则新增）
export function saveSession(ctx: common.UIAbilityContext, session: ChatSession): void {
  if (!session.messages.length) return
  try {
    const store = preferences.getPreferencesSync(ctx, { name: STORE_NAME })
    const raw = store.getSync(KEY_SESSIONS, '[]') as string
    const arr = JSON.parse(raw) as ChatSession[]
    const idx = arr.findIndex(s => s.id === session.id)
    if (idx >= 0) {
      arr[idx] = session        // 更新已有会话
    } else {
      arr.push(session)         // 新增会话
    }
    store.putSync(KEY_SESSIONS, JSON.stringify(arr))
    store.flushSync()           // 同步刷盘，确保数据写入文件
  } catch (e) {
    console.error('[ChatPersist] saveSession failed', JSON.stringify(e))
  }
}

// 删除指定会话
export function deleteSession(ctx: common.UIAbilityContext, sessionId: string): void {
  try {
    const store = preferences.getPreferencesSync(ctx, { name: STORE_NAME })
    const raw = store.getSync(KEY_SESSIONS, '[]') as string
    const arr = (JSON.parse(raw) as ChatSession[]).filter(s => s.id !== sessionId)
    store.putSync(KEY_SESSIONS, JSON.stringify(arr))
    store.flushSync()
  } catch (e) {
    console.error('[ChatPersist] deleteSession failed', JSON.stringify(e))
  }
}
```

**关键 API：**

| API | 说明 |
|---|---|
| `preferences.getPreferencesSync(ctx, { name })` | 获取/创建 Preferences 实例（同步） |
| `store.getSync(key, defaultValue)` | 读取值，不存在时返回默认值 |
| `store.putSync(key, value)` | 写入值（内存级，未持久化） |
| `store.flushSync()` | 将内存数据同步写入磁盘文件（必须调用！） |

> **`flushSync` 的重要性**：`putSync` 只更新内存中的缓存，App 异常退出时数据可能丢失。需要 `flushSync` 触发写盘。

---

## 四、自动保存会话的时机

AI 消息采用打字机动画逐字展示，动画结束时 `vm.pendingResponse` 会从字符串变回 `''`。  
这是一个天然的「AI 回复完成」信号，用 `@Monitor` 监听它来触发保存：

```typescript
// components/ChatTabComp.ets

// 打字机动画结束时 pendingResponse 变回 ''，此时 AI 消息已推入 historyMessage
// Tabs 切换不触发 aboutToDisappear，所以在这里保存而不是在销毁时
@Monitor('vm.pendingResponse')
onResponseConsumed(): void {
  if (this.vm.pendingResponse === '' && this.vm.historyMessage.length > 0) {
    this.persistSession()
  }
}

private persistSession(): void {
  if (this.vm.historyMessage.length === 0) return

  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
  if (!ctx) return

  const messages = this.vm.historyMessage
  const firstUser = messages.find(m => m.role === 'user')
  const title = firstUser
    ? firstUser.content.substring(0, 20) + (firstUser.content.length > 20 ? '...' : '')
    : '新对话'
  const last = messages[messages.length - 1]
  const preview = last.content.substring(0, 30) + (last.content.length > 30 ? '...' : '')

  const session: ChatSession = {
    id: this.vm.sessionId,
    title,
    preview,
    createTime: messages[0].createTime,
    updateTime: last.createTime,
    messages
  }
  saveSession(ctx, session)
}
```

**为什么不在 `aboutToDisappear` 保存？**  
`Tabs` 在切换 Tab 时不会销毁/重建子组件，`aboutToDisappear` 只在 `HomePage` 整体销毁时才触发。  
如果用户发送了消息后直接切换 Tab，`aboutToDisappear` 永远不会调用，数据就丢失了。  
`@Monitor('vm.pendingResponse')` 每次 AI 回复完成都触发，更可靠。

---

## 五、历史记录列表页：ChatHistoryPage

### 5.1 左滑删除

鸿蒙 `ListItem` 内置了 `swipeAction` 属性，直接支持左滑显示自定义按钮，无需手写手势：

```typescript
// pages/ChatHistoryPage.ets
ListItem() {
  // 列表项内容...
}
.swipeAction({
  end: this.deleteButton(session.id)  // 左滑时从右侧滑出
})
.onClick(() => {
  HMRouterMgr.push({
    navigationId: NAV_ID,
    pageUrl: route.PAGE_CHAT,
    param: session    // ← 把整个 session 传给 ChatPage
  })
})

@Builder
deleteButton(sessionId: string) {
  Button('删除')
    .width(72).height('100%')
    .fontSize(14)
    .backgroundColor('#FF4D4F')
    .fontColor(Color.White)
    .onClick(() => { this.onDelete(sessionId) })
}
```

**注意：`@Builder` 方法必须用箭头函数形式定义（或绑定 this），否则 `this` 会丢失：**

```typescript
// ❌ 普通方法：this 在回调里丢失
@Builder deleteButton(id: string) { ... }

// ✅ 删除操作在独立方法里，Builder 只负责 UI，this 不会丢失
private onDelete(sessionId: string): void {
  deleteSession(this.ctx!, sessionId)
  this.sessions = this.sessions.filter(s => s.id !== sessionId)
}
```

### 5.2 时间格式化

```typescript
private formatTime(ms: number): string {
  const d = new Date(ms)
  const now = new Date()
  const isToday = d.toDateString() === now.toDateString()
  if (isToday) {
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
  return `${d.getMonth() + 1}/${d.getDate()}`
}
```

今天显示 `HH:mm`，历史日期显示 `M/D`，符合主流 IM 产品的惯例。

---

## 六、Bug 修复一：点击历史记录后页面空白

### 6.1 现象

从「消息记录」列表点击任意一条历史会话，进入 `ChatPage` 后消息列表空白，只能重新发消息，旧消息完全看不到。

### 6.2 根本原因

`ChatHistoryPage` 推路由时把 `session` 作为 `param` 传递：

```typescript
// pages/ChatHistoryPage.ets
HMRouterMgr.push({
  navigationId: NAV_ID,
  pageUrl: route.PAGE_CHAT,
  param: session    // ← 传了参数
})
```

但 `ChatPage.aboutToAppear()` 完全没有读取这个参数，每次都用空的 `ChatViewModel`：

```typescript
// ❌ 修复前：ChatPage.ets
@Local vm: ChatViewModel = new ChatViewModel()   // 永远是空的

aboutToAppear(): void {
  // 没有任何读取路由参数的代码
  try {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
  } catch (_) {}
  this.initKeyboardListener()
}
```

### 6.3 修复方案

HMRouter 提供 `HMRouterMgr.getCurrentParam(type)` 接口读取路由参数：

| 参数类型 | 对应 `HMParamType` | 说明 |
|---|---|---|
| `push({ param })` 传入的对象 | `routeParam` | 最常用，本次使用此类型 |
| URL 中的 query 参数 | `urlParam` | 适合 URI 跳转场景 |
| 正则匹配结果 | `regexParam` | 适合动态路由 |
| 以上全部 | `all`（默认） | 返回 `HMPageParam` 对象，包含所有类型 |

```typescript
// ✅ 修复后：ChatPage.ets
import { HMRouter, HMRouterMgr, HMParamType } from '@hadss/hmrouter'
import { ChatSession } from '../models/chatModel'

aboutToAppear(): void {
  // 读取路由参数，有历史会话时加载消息
  const session = HMRouterMgr.getCurrentParam(HMParamType.routeParam) as ChatSession | null
  if (session?.messages?.length) {
    this.vm.historyMessage = session.messages
    this.vm.sessionId = session.id
  }
  try {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
  } catch (_) {}
  this.initKeyboardListener()
}
```

**为什么用 `HMParamType.routeParam` 而不是默认的 `all`？**  
用 `all` 时返回 `HMPageParam` 对象，需要额外取 `.data` 字段，类型断言更繁琐：
```typescript
// all 模式的写法（繁琐）
const pageParam = HMRouterMgr.getCurrentParam() as HMPageParam
const session = pageParam?.data as ChatSession
```
直接用 `routeParam` 模式，返回值就是 `param` 字段本身，更简洁。

---

## 七、Bug 修复二：Tab Bar 随键盘弹起上移

### 7.1 现象

进入「AI 助手」Tab，点击输入框，键盘弹起时底部 Tab Bar 也随着一起往上跳，视觉上整个页面内容区像是被顶上去了。

### 7.2 根本原因分析

`ChatTabComp.aboutToAppear()` 设置了 `KeyboardAvoidMode.NONE`（禁用系统自动避让），并通过手动 `padding.bottom` 处理键盘高度。这部分逻辑本身是正确的。

但 `Tabs` 组件有自己的键盘响应机制：当键盘弹起时，`Tabs` 会**自动缩小 `TabContent` 区域的高度**，把腾出来的空间留给键盘，同时 Tab Bar 在视觉上向上移动。

这个行为与 `KeyboardAvoidMode.NONE` 的设置无关，是 `Tabs` 组件层面的默认行为。

```
键盘弹起前：
┌─────────────────────┐
│   ChatTabComp 内容   │  TabContent（layoutWeight:1）
│   （消息列表）        │
│   （输入框）         │
├─────────────────────┤
│    Tab Bar（56vp）   │
└─────────────────────┘

键盘弹起后（❌ 未修复）：
┌─────────────────────┐
│   ChatTabComp 内容   │  TabContent 被 Tabs 压缩
│   （消息列表）        │
├─────────────────────┤
│  Tab Bar（随内容上移）│  ← Tab Bar 跟着跳上来
├─────────────────────┤
│      键盘区域         │
└─────────────────────┘
```

### 7.3 修复方案

在 `ChatTabComp` 的 Column 上加 `.expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])`：

```typescript
// ✅ 修复后：components/ChatTabComp.ets
build() {
  Column() {
    // 标题栏、消息列表、输入框...
  }
  .width('100%')
  .height('100%')
  .padding({ bottom: this.keyboardHeight > 0
    ? Math.max(0, this.keyboardHeight - 56 - WindowUtil.getBottomAvoidHeight())
    : 0
  })
  .expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])  // ← 新增
}
```

`expandSafeArea` 的作用：声明该组件**自行处理键盘安全区**，`Tabs` 不再介入缩小 `TabContent`，Tab Bar 就不会再随键盘弹起。

```
键盘弹起后（✅ 修复后）：
┌─────────────────────┐
│   ChatTabComp 内容   │  TabContent 高度不变
│   （消息列表）        │
│   （输入框）         │ ← 通过 padding.bottom 贴键盘
├─────────────────────┤
│    Tab Bar（不动）   │  ← Tab Bar 保持原位
├─────────────────────┤
│      键盘区域         │
└─────────────────────┘
```

### 7.4 `expandSafeArea` 参数速查

```typescript
.expandSafeArea(types?: SafeAreaType[], edges?: SafeAreaEdge[])
```

| 枚举 | 值 | 说明 |
|---|---|---|
| `SafeAreaType.SYSTEM` | 系统安全区（状态栏、虚拟导航栏） | |
| `SafeAreaType.CUTOUT` | 挖孔屏摄像头区域 | |
| `SafeAreaType.KEYBOARD` | 键盘弹出区域 | |
| `SafeAreaEdge.TOP` | 顶部边缘扩展 | |
| `SafeAreaEdge.BOTTOM` | 底部边缘扩展 | ← 本次使用 |
| `SafeAreaEdge.START` | 起始边（左/RTL右）扩展 | |
| `SafeAreaEdge.END` | 结束边扩展 | |

---

## 八、整合视角：完整的聊天记录功能链路

```
用户发消息
  │
  ▼
ChatController.sendMessage()
  └─ 构建 ChatMessage，推入 vm.historyMessage
  └─ 调用 API，拿到回复
  └─ 设置 vm.pendingResponse（触发打字机动画）

打字机动画结束
  └─ vm.pendingResponse = ''
  └─ @Monitor 触发 onResponseConsumed()
  └─ persistSession() → saveSession() → Preferences 写盘

用户进入「我的」→「消息记录」
  └─ ChatHistoryPage.aboutToAppear()
  └─ loadSessions() 读取 Preferences
  └─ 按 updateTime 降序展示列表

用户点击某条历史记录
  └─ HMRouterMgr.push({ param: session })
  └─ ChatPage.aboutToAppear()
  └─ getCurrentParam(HMParamType.routeParam)
  └─ vm.historyMessage = session.messages   ← Bug 修复点
  └─ 消息列表正常渲染

用户左滑删除
  └─ deleteSession() → Preferences 删除
  └─ 本地 filter 移除（不重新读文件）
```

---

## 九、常见踩坑

### 坑 1：路由传参后忘记接收

❌ `push({ param: data })` → 目标页面没有 `getCurrentParam()` → 页面永远用空数据初始化  
✅ 目标页的 `aboutToAppear()` 里第一件事就是读参数，再做初始化

### 坑 2：用 `all` 类型接收参数时漏取 `.data`

```typescript
// ❌ 这样拿到的是 HMPageParam 对象，不是 session 本身
const session = HMRouterMgr.getCurrentParam() as ChatSession

// ✅ 方式一：指定 routeParam 类型
const session = HMRouterMgr.getCurrentParam(HMParamType.routeParam) as ChatSession

// ✅ 方式二：用 all 类型，需额外取 .data
const session = (HMRouterMgr.getCurrentParam() as HMPageParam)?.data as ChatSession
```

### 坑 3：Preferences 写完不 flush

❌ `putSync(key, value)` 只写内存，App 崩溃时数据丢失  
✅ 每次写操作后都调用 `flushSync()`

### 坑 4：Tabs 内使用键盘避让遗漏 expandSafeArea

❌ 只设置 `KeyboardAvoidMode.NONE` + 手动 `padding.bottom`  
  → `Tabs` 自身仍会压缩 `TabContent`，Tab Bar 随键盘弹起  
✅ 额外加 `.expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])`

### 坑 5：Tabs 不触发子组件的 aboutToDisappear

❌ 在 `ChatTabComp.aboutToDisappear()` 里保存数据  
  → 切 Tab 时不触发，数据丢失  
✅ 用 `@Monitor` 监听状态变化，每次 AI 回复完成时自动保存

### 坑 6：左滑删除 @Builder 里 this 丢失

❌ 在 `@Builder` 内直接写 `this.onDelete(id)`，有时 this 指向不对  
✅ 把业务逻辑提取成独立的 `private onDelete()` 方法，`@Builder` 只做 UI

---

## 十、参考文档

- [Preferences - 鸿蒙官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-preferences)
- [List 组件 swipeAction](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-list)
- [expandSafeArea](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-expand-safe-area)
- [HMRouter 路由传参](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hmrouter-param)
- [Monitor 装饰器](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-monitor)
