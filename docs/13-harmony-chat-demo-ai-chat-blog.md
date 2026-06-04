# 鸿蒙 ArkTS 聊天 Demo 功能复盘：真实 SSE、多轮会话、暂停输出、历史记录与防崩溃修复

> 项目：`harmony-chat-demo`  
> 分支：`ai-chat`  
> 复盘主题：围绕最近几次提交，完整梳理聊天 Demo 从基础聊天，到真实 SSE 流式回复、多轮对话、新会话、暂停输出、历史记录恢复、暗黑模式以及防崩溃修复的实现过程。

---

## 一、今天主要完成了什么

这次主要围绕 `ai-chat` 分支继续完善聊天 Demo。目标不是单纯做一个“能发消息”的页面，而是尽量模拟真实业务项目里的聊天模块，把页面、状态、请求、持久化、主题和异常修复都串起来。

从最近的提交来看，今天重点完成了这些内容：

1. 接入真实 SSE 流式接口，前端不再只使用假数据。
2. 支持 AI 回复流式输出，后端返回一段，前端就追加一段。
3. 新增“停止”按钮，可以在生成中主动暂停输出。
4. 新增“+ 新会话”能力，当前对话结束后可以开启新的会话。
5. 每次发送时携带历史上下文，实现一轮、二轮、三轮连续对话。
6. 聊天历史支持持久化保存，并能从历史记录中恢复会话。
7. 增加暗黑模式，使用统一主题状态管理，而不是每个子组件自己读持久化。
8. 修复历史记录点击后崩溃的问题。
9. 修复历史会话恢复后最后一条 AI 回复丢失、一直显示“AI 思考中...”的问题。
10. 处理 ArkTS 严格模式下的类型报错，例如 `arkts-no-any-unknown`。

最终效果就是：聊天页面能够正常发送消息、真实接收后端 SSE 回复、连续多轮对话、暂停生成、新建会话、查看历史、恢复历史，并且不会因为历史数据不完整导致页面崩溃。

---

## 二、整体架构思路

这次聊天 Demo 没有把所有逻辑都写在一个页面里，而是逐渐往公司项目里的分层方式靠近。

当前聊天模块大致可以拆成这几层：

```text
entry 首页
  ↓
ChatTabComp 聊天页容器组件
  ↓
ChatViewModel 页面状态
  ↓
ChatController 页面业务控制器
  ↓
ChatBiz 请求业务封装
  ↓
SSE 后端接口
```

页面展示相关的组件拆成：

```text
ChatTabComp
  ├── ChatListComp      消息列表
  └── ChatInputComp     底部输入框
```

历史记录相关拆成：

```text
ChatHistoryPage        历史记录页面
ChatPersist            本地持久化工具
ChatLoadState          跨页面加载信号
```

模型层主要有：

```text
ChatMessage            UI 响应式消息对象
ChatMessagePlain       持久化用普通消息对象
ChatHistoryItem        发给后端的上下文消息
ChatSession            一整个会话
```

这个分层的好处是：UI 组件只负责展示；ViewModel 负责保存页面状态；Controller 负责处理发送、停止、流式更新；Biz 负责封装请求；Persist 负责保存和读取本地历史；Model 负责统一数据结构。这样后面继续加功能时，不会所有代码都堆在页面组件里。

---

## 三、页面状态设计：ChatViewModel

聊天页面最核心的状态都放在 `ChatViewModel` 里。

```ts
@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = ''
  @Trace historyMessage: ChatMessage[] = []
  @Trace isLoading: boolean = false
  @Trace sessionId: string = ''

  resetForNewSession(): void {
    this.sessionId = Date.now().toString()
    this.historyMessage = []
    this.inputContent = ''
    this.isLoading = false
  }

  resetRuntimeState(): void {
    this.inputContent = ''
    this.isLoading = false
  }
}
```

几个字段的作用分别是：

| 字段 | 作用 |
|---|---|
| `inputContent` | 输入框当前内容 |
| `historyMessage` | 当前会话里的所有消息 |
| `isLoading` | AI 是否正在生成 |
| `sessionId` | 当前会话 ID |

这里用 `@ObservedV2` 和 `@Trace` 的原因是：当字段变化时，ArkUI 可以感知状态变化，并自动刷新对应 UI。

例如 AI 回复流式输出时，只需要不断修改：

```ts
this.activeAiMessage.content += safeChunk
```

因为 `content` 是 `@Trace` 字段，所以页面上的 AI 气泡内容会自动更新。这也是这次实现流式输出的关键点。

---

## 四、为什么使用“AI 占位消息 + content 追加”的方案

一开始做聊天功能时，比较容易想到的方案是：

```text
收到一段 chunk
  ↓
更新 streamingContent
  ↓
页面额外渲染一个临时气泡
  ↓
流式结束后再把完整 AI 消息 push 到 historyMessage
```

这种方案能跑，但是状态会比较绕。因为页面里同时存在：

```text
historyMessage      已经完成的历史消息
streamingContent    当前正在生成的临时内容
```

后面做历史记录、暂停输出、保存会话时，需要额外判断这条临时消息什么时候合并进历史，容易出现状态不同步。

这次最终采用的是更直接的方案：

```text
用户点击发送
  ↓
historyMessage 先 push 用户消息
  ↓
historyMessage 再 push 一条空的 AI 消息
  ↓
保存这条 AI 消息引用 activeAiMessage
  ↓
每收到一个 SSE chunk，就 activeAiMessage.content += chunk
  ↓
UI 根据 @Trace content 自动刷新
```

核心代码思路：

```ts
const userMessage = new ChatMessage()
userMessage.role = 'user'
userMessage.content = content

const aiMessage = new ChatMessage()
aiMessage.role = 'assistant'
aiMessage.content = ''

this.vm.historyMessage.push(userMessage)
this.vm.historyMessage.push(aiMessage)
this.activeAiMessage = aiMessage
```

然后 SSE 每返回一段内容：

```ts
onChunk: (chunk: string) => {
  if (!this.activeAiMessage) {
    return
  }

  const safeChunk: string = chunk ? chunk : ''
  this.activeAiMessage.content += safeChunk
}
```

这种方案的优点是：消息列表永远只看 `historyMessage`；正在生成的 AI 回复也是历史消息数组中的一项；流式输出时不需要反复重建数组；停止生成时可以直接修改当前 AI 消息；保存历史时只需要保存整个 `historyMessage` 的纯数据版本。

---

## 五、真实 SSE 接口接入

之前聊天 Demo 可以先用假接口模拟回复，比如固定回复一句话，或者延迟两秒显示“AI 思考中...”。但真实项目里，AI 回复一般不是一次性返回完整文本，而是通过 SSE 一段一段返回。

这次引入真实 SSE 请求后，大致流程是：

```text
用户输入内容
  ↓
Controller 收集当前输入和历史上下文
  ↓
调用 ChatBiz.sendMessageStream()
  ↓
后端持续返回 chunk
  ↓
前端 onChunk 追加到 AI 气泡
  ↓
后端发送 done
  ↓
前端 onDone 收尾
```

在 `ChatController` 中，核心处理分成三个回调：

```ts
{
  onChunk: (chunk: string) => {
    // 收到一段内容，追加到当前 AI 消息
  },

  onDone: (meta: SseDoneMeta) => {
    // 流式结束，更新 sessionId / messageId，关闭 loading
  },

  onError: (errMsg: string) => {
    // 请求失败，显示失败文案，关闭 loading
  }
}
```

`onChunk` 负责流式追加：

```ts
const safeChunk: string = chunk ? chunk : ''
this.activeAiMessage.content += safeChunk
```

`onDone` 负责收尾：

```ts
if (meta.sessionId) {
  this.vm.sessionId = meta.sessionId

  if (this.activeAiMessage) {
    this.activeAiMessage.sessionId = meta.sessionId
  }
}

if (meta.messageId && this.activeAiMessage) {
  this.activeAiMessage.id = meta.messageId
}

this.vm.isLoading = false
this.activeAiMessage = null
this.currentRequest = null
```

这里有两个细节很重要：第一，后端可能会返回真正的 `sessionId`，所以前端需要同步更新当前会话 ID；第二，`isLoading` 必须在结束时设置为 `false`，否则输入框会一直处于生成中状态，停止按钮也不会恢复成发送按钮。

---

## 六、多轮对话：每次发送都携带历史上下文

要实现连续追问，不是只把当前输入发给后端，而是要把之前的对话历史也带上。

例如：

```text
第一轮：我：你好
AI：你好，有什么可以帮你？

第二轮：我：帮我总结一下刚才的话
```

如果第二轮只发“帮我总结一下刚才的话”，后端不知道“刚才的话”是什么。

所以发送前需要把当前会话里的历史消息转换成后端需要的上下文格式：

```ts
const historySnapshot: ChatHistoryItem[] = this.vm.historyMessage
  .filter((m: ChatMessage): boolean => {
    const safeContent: string = m.content ? m.content : ''
    return safeContent.length > 0
  })
  .map((m: ChatMessage): ChatHistoryItem => {
    const item = new ChatHistoryItem()
    item.role = m.role ? m.role : 'assistant'
    item.content = m.content ? m.content : ''
    return item
  })
```

这里有几个点：只传 `role` 和 `content` 给后端；空消息不传，比如正在生成但还没有内容的 AI 占位消息；所有 `content` 都做空值防御，避免历史脏数据导致 `.length` 崩溃；使用 `ChatHistoryItem` class，而不是随手写对象字面量，避免 ArkTS 对未声明对象字面量报错。

---

## 七、新会话功能

新会话功能看起来简单，实际要考虑状态重置。

点击“+ 新会话”时，不能只清空输入框，也不能只清空消息列表。应该把当前会话相关状态都重置掉：

```ts
resetForNewSession(): void {
  this.sessionId = Date.now().toString()
  this.historyMessage = []
  this.inputContent = ''
  this.isLoading = false
}
```

点击按钮时：

```ts
private newSession(): void {
  if (this.vm.isLoading) {
    return
  }

  this.vm.resetForNewSession()
}
```

这里有一个小细节：如果当前 AI 正在生成，不允许直接新建会话。原因是如果生成中直接清空消息列表，当前 `activeAiMessage` 还可能被 SSE 回调继续修改，导致 UI 状态错乱。所以生成中应该先点“停止”，等请求结束后再新建会话。

---

## 八、暂停输出功能

暂停输出的关键是保存当前请求对象。

在 Controller 里维护：

```ts
private currentRequest: http.HttpRequest | null = null
private activeAiMessage: ChatMessage | null = null
```

发起请求时：

```ts
this.currentRequest = this.biz.sendMessageStream(...)
```

用户点击停止时：

```ts
stopGeneration(): void {
  if (this.currentRequest) {
    try {
      this.currentRequest.destroy()
    } catch {
    }

    this.currentRequest = null
  }

  if (this.activeAiMessage) {
    const oldContent: string = this.activeAiMessage.content ? this.activeAiMessage.content : ''

    if (oldContent.length > 0) {
      this.activeAiMessage.content = oldContent + '\n\n[已停止]'
    } else {
      this.activeAiMessage.content = '[已停止]'
    }

    this.activeAiMessage = null
  }

  this.vm.isLoading = false
}
```

这段逻辑主要做三件事：销毁当前 SSE 请求；给当前 AI 消息追加 `[已停止]` 标记；把 `isLoading` 设置成 `false`，让输入框恢复可用。

---

## 九、输入框状态：发送按钮和停止按钮切换

`ChatInputComp` 根据 `isGenerating` 决定显示“发送”还是“停止”。

```ts
if (this.isGenerating) {
  Button('停止')
    .onClick(() => {
      this.onStop()
    })
} else {
  Button('发送')
    .onClick(() => {
      this.onSend()
    })
    .enabled(this.inputContent.trim().length > 0)
}
```

同时生成中禁用输入框：

```ts
.enabled(!this.isGenerating)
```

这样交互比较清晰：没有输入内容时，发送按钮不可点；有输入内容时，可以发送；AI 生成中，输入框不可编辑，按钮变成“停止”；停止或生成结束后，按钮恢复为“发送”。

---

## 十、历史记录持久化

历史记录功能的目标是：用户完成一轮对话后，即使新建会话或者离开页面，之前的聊天记录也能在历史页看到，并且可以点击恢复。

整体流程是：

```text
AI 回复结束
  ↓
vm.isLoading 从 true 变成 false
  ↓
ChatTabComp 监听到状态变化
  ↓
persistSession()
  ↓
转换数据结构
  ↓
saveSession()
  ↓
Preferences 保存到本地
```

监听逻辑：

```ts
@Monitor('vm.isLoading')
onLoadingChange(): void {
  if (!this.vm.isLoading && this.vm.historyMessage.length > 0) {
    this.persistSession()
  }
}
```

也就是说，每次 AI 回复结束后，自动保存当前会话。

---

## 十一、为什么不能直接保存 ChatMessage

这次最关键的坑就是这里。

`ChatMessage` 是 UI 层响应式对象：

```ts
@ObservedV2
export class ChatMessage {
  id: string = ''
  role: string = ''
  @Trace content: string = ''
  createTime: number = 0
  sessionId: string = ''
}
```

其中 `content` 是 `@Trace` 字段。`@Trace` 很适合做 UI 响应式刷新，但是不适合直接 `JSON.stringify`。因为它可能不是普通可枚举字段，直接序列化时会丢失内容。

一开始出现的 bug 是：当前页面里 AI 回复显示正常，点击“+ 新会话”后进入历史记录，再点回刚才那条历史，最后一条 AI 回复变成“AI 思考中...”。原因就是保存时把 `ChatMessage[]` 直接 JSON.stringify 了，结果 AI 消息的 `content` 没有被正确保存。

所以需要定义一个纯数据版本：

```ts
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
}
```

会话模型也应该使用：

```ts
export class ChatSession {
  id: string = ''
  title: string = ''
  preview: string = ''
  createTime: number = 0
  updateTime: number = 0
  messages: ChatMessagePlain[] = []
}
```

核心原则是：UI 展示用 `ChatMessage`，本地保存用 `ChatMessagePlain`。

---

## 十二、保存时：ChatMessage 转 ChatMessagePlain

保存会话时，不能直接：

```ts
session.messages = this.vm.historyMessage
```

而是要手动转换：

```ts
const sourceMessages: ChatMessage[] = this.vm.historyMessage
const plainMessages: ChatMessagePlain[] = []

for (let i = 0; i < sourceMessages.length; i++) {
  const source: ChatMessage = sourceMessages[i]

  const plain = new ChatMessagePlain()
  plain.id = source.id ? source.id : `${this.vm.sessionId}_${i}`
  plain.role = source.role ? source.role : 'assistant'
  plain.content = source.content ? source.content : ''
  plain.createTime = source.createTime ? source.createTime : Date.now()
  plain.sessionId = source.sessionId ? source.sessionId : this.vm.sessionId

  plainMessages.push(plain)
}
```

然后再保存：

```ts
const session = new ChatSession()
session.id = this.vm.sessionId
session.title = title
session.preview = preview
session.createTime = createTime
session.updateTime = updateTime
session.messages = plainMessages

saveSession(ctx, session)
```

这一步修复了“历史恢复后 AI 回复内容丢失”的问题。

---

## 十三、恢复时：ChatMessagePlain 转 ChatMessage

读取历史时，Preferences 里拿出来的是普通对象，不是响应式对象。

所以加载历史会话时，也不能直接：

```ts
this.vm.historyMessage = target.messages
```

而是要重新 new `ChatMessage`：

```ts
const restored: ChatMessage[] = []
const sourceMessages: ChatMessagePlain[] = target.messages ? target.messages : []

for (let i = 0; i < sourceMessages.length; i++) {
  const plain: ChatMessagePlain = sourceMessages[i]

  const msg = new ChatMessage()
  msg.id = plain.id ? plain.id : `${id}_${i}`
  msg.role = plain.role ? plain.role : 'assistant'
  msg.content = plain.content ? plain.content : ''
  msg.createTime = plain.createTime ? plain.createTime : Date.now()
  msg.sessionId = plain.sessionId ? plain.sessionId : id

  restored.push(msg)
}

this.vm.sessionId = target.id ? target.id : id
this.vm.historyMessage = restored
this.vm.inputContent = ''
this.vm.isLoading = false
```

这样恢复出来的消息重新具备 `@ObservedV2 / @Trace` 能力，后续继续对话也比较稳定。

---

## 十四、历史记录点击恢复的实现

历史页点击某条历史记录时，没有直接把整个 session 对象强塞回聊天页，而是使用一个跨页面状态信号：

```ts
getChatLoadState().pendingSessionId = session.id
HMUtil.pop()
```

然后聊天页监听：

```ts
@Monitor('chatLoadState.pendingSessionId')
onPendingSessionChange(): void {
  const id: string = this.chatLoadState.pendingSessionId

  if (id) {
    this.loadSession(id)
    this.chatLoadState.pendingSessionId = ''
  }
}
```

这样设计的好处是：历史页只负责告诉聊天页“我要加载哪条会话”；真正的数据读取和恢复逻辑仍然留在 `ChatTabComp`；避免跨页面传递复杂对象导致响应式对象丢失；也更适合底部 Tab 页面结构。

---

## 十五、消息列表渲染和防崩溃处理

最早的崩溃日志是：

```text
Cannot read property length of undefined
```

定位到 `ChatListComp.ets` 中对某个字段直接 `.length`。例如这类代码有风险：

```ts
this.vm.streamingContent.length
this.msg.content.length
```

因为历史记录里的旧数据、异常数据、未完整保存的数据，都可能导致 `content` 是 `undefined`。

所以消息展示时要统一做安全处理：

```ts
private getSafeContent(): string {
  if (this.msg.content) {
    return this.msg.content
  }

  return ''
}
```

然后再判断长度：

```ts
const content: string = this.getSafeContent()

if (content.length > 0) {
  return content
}
```

这样就不会出现 `undefined.length` 崩溃。

---

## 十六、区分“正在思考”和“历史数据损坏”

还有一个容易误导的问题：如果 assistant 消息内容为空，到底应该显示什么？

一开始直接写成：

```ts
Text(content.length > 0 ? content : 'AI 思考中...')
```

这样会导致历史会话恢复后，如果某条 AI 回复内容丢了，也会一直显示“AI 思考中...”。但实际上它不是正在思考，而是旧数据没有保存完整。

所以后来改成了更精确的判断：

```text
如果 assistant content 有内容
  → 显示 content

如果 assistant content 为空，并且当前正在生成，并且它是最后一条消息
  → 显示 AI 思考中...

如果 assistant content 为空，但不是正在生成
  → 显示 该条回复内容未保存完整
```

判断逻辑：

```ts
private isLastLiveThinking(item: ChatMessage): boolean {
  if (!this.vm.isLoading) {
    return false
  }

  if (item.role !== 'assistant') {
    return false
  }

  const content: string = item.content ? item.content : ''

  if (content.length > 0) {
    return false
  }

  if (!this.vm.historyMessage || this.vm.historyMessage.length === 0) {
    return false
  }

  const last: ChatMessage = this.vm.historyMessage[this.vm.historyMessage.length - 1]

  return last.id === item.id
}
```

这样 UI 就能正确区分当前实时生成中的 AI 回复和历史数据中丢失内容的 AI 回复。

---

## 十七、ArkTS 严格类型问题：arkts-no-any-unknown

修 bug 时还遇到了 ArkTS 编译报错：

```text
Use explicit types instead of "any", "unknown" (arkts-no-any-unknown)
```

这个问题主要出现在几类代码里。

### 1. `catch (_)`

TypeScript 里经常写：

```ts
try {
  // ...
} catch (_) {
}
```

但 ArkTS 严格模式下，`_` 可能会被推断成 `unknown`，从而触发报错。如果不需要错误对象，直接写：

```ts
try {
  // ...
} catch {
}
```

### 2. 数组下标取值

不要让 ArkTS 自己猜类型：

```ts
const last = this.vm.historyMessage[this.vm.historyMessage.length - 1]
```

改成显式类型：

```ts
const last: ChatMessage = this.vm.historyMessage[this.vm.historyMessage.length - 1]
```

### 3. `find()` 返回值

`find()` 可能返回 `undefined`，所以要写清楚：

```ts
const target: ChatSession | undefined = sessions.find((s: ChatSession): boolean => {
  return s.id === id
})
```

### 4. `map()` 返回值

也尽量写清楚返回类型：

```ts
.map((m: ChatMessage): ChatHistoryItem => {
  const item = new ChatHistoryItem()
  item.role = m.role ? m.role : 'assistant'
  item.content = m.content ? m.content : ''
  return item
})
```

这部分虽然比较啰嗦，但能帮助代码更符合 ArkTS 的静态类型要求，也更接近真实项目里的规范写法。

---

## 十八、暗黑模式和 Provider 统一管理

除了聊天功能，这次还整理了主题管理。

之前如果每个子组件都自己读取持久化配置，就会出现：

```text
ChatListComp 读一次
ChatInputComp 读一次
HistoryPage 读一次
ProfilePage 读一次
```

这样的问题是重复代码多、状态不统一、切换主题时不同组件容易不同步、后续维护成本高。

所以后面改成由上层统一管理主题状态，再通过 Provider / Consumer 或公共状态对象下发给子组件。

子组件只需要：

```ts
@Local theme: ThemeState = getThemeState()
```

然后使用统一的主题字段：

```ts
.backgroundColor(this.theme.bg)
.fontColor(this.theme.textPrimary)
.backgroundColor(this.theme.assistantBubbleBg)
```

这样白天模式和黑夜模式切换时，聊天页、输入框、历史页的颜色都能保持一致。

---

## 十九、本次修复的几个关键 bug

### bug 1：点击历史记录后崩溃

表现：

```text
点击历史记录
  ↓
随便点一条会话
  ↓
应用崩溃
```

原因：UI 渲染时直接读取 `undefined.length`。

修复：所有 `.length` 前先保证它是字符串。

```ts
const content: string = this.msg.content ? this.msg.content : ''
```

### bug 2：历史恢复后最后一条 AI 回复丢失

表现：当前页面 AI 回复正常显示，进入历史记录并点回会话后，最后一条 AI 回复变成“AI 思考中...”。

原因：`ChatMessage.content` 是 `@Trace` 字段，直接 `JSON.stringify(ChatMessage)` 时 content 丢失。

修复：

```text
保存前：ChatMessage -> ChatMessagePlain
恢复时：ChatMessagePlain -> ChatMessage
```

### bug 3：历史中的空 assistant 消息一直显示 AI 思考中

原因：只要 assistant content 为空，就显示 AI 思考中。

修复：只有当前正在生成，并且这条消息是最后一条 assistant 空消息，才显示 AI 思考中。否则显示“该条回复内容未保存完整”。

### bug 4：ArkTS 类型检查报错

表现：

```text
Use explicit types instead of "any", "unknown"
```

修复：

```text
catch (_)  → catch {}
const xxx = arr[i] → const xxx: XxxType = arr[i]
find(...) → const xxx: XxxType | undefined = ...
```

---

## 二十、最终测试流程

这次功能完成后，可以按下面流程测试：

```text
1. 打开 App，进入 AI 助手页面。
2. 输入第一句话，点击发送。
3. 观察 AI 是否开始流式输出。
4. 输出过程中点击“停止”，检查是否能终止。
5. 再发送第二轮问题，检查是否能携带历史上下文。
6. 等完整回复结束后，点击“+ 新会话”。
7. 进入历史记录页面。
8. 点击刚才那条历史会话。
9. 检查用户消息和 AI 回复是否都能完整恢复。
10. 再继续发送消息，检查恢复后的会话还能继续对话。
11. 切换暗黑模式，检查聊天列表、输入框、历史页颜色是否统一。
12. 重启 App，再进入历史记录，检查持久化数据是否仍然存在。
```

如果之前已经保存过错误历史，需要先清理应用数据。因为旧数据里的 AI 回复内容已经丢失，代码修好后也无法凭空恢复。

---

## 二十一、这次学到的关键点

### 1. UI 响应式对象和持久化对象最好分开

`ChatMessage` 适合 UI 响应式展示，但不适合直接保存。

真实项目里经常需要区分：

```text
ViewModel Model      页面响应式状态
DTO / Plain Model    接口传输、持久化数据
```

这次的 `ChatMessage` 和 `ChatMessagePlain` 就是这个思路。

### 2. 流式输出不一定要单独维护 streamingContent

如果直接把 AI 占位消息放入 `historyMessage`，再通过 `@Trace content` 更新内容，代码会更简单。

这个方案比单独维护 `streamingContent` 更适合做历史保存、暂停生成、多轮上下文和消息列表统一渲染。

### 3. ArkTS 比 TypeScript 更强调静态类型

在 TypeScript 里能跑的写法，ArkTS 不一定能过。

尤其是对象字面量、`any / unknown`、`catch(e)`、`find` 返回值、数组下标取值，这些地方都要写得更明确。

### 4. 保存历史一定要考虑异常数据

真实项目里不能假设本地数据永远正确。所以 UI 渲染时要对 `content`、`messages`、`sessionId`、`id`、`createTime` 做兜底。只要涉及 `.length`、`substring()`、数组下标，都要先确保数据存在。

### 5. 页面之间不要随便传复杂响应式对象

历史页点击会话时，最好只传 `sessionId`，再由聊天页自己加载和恢复数据。这样比直接传整个 `ChatSession` 更稳，也更符合“页面只传信号，数据由目标页面自己恢复”的思路。

---

## 二十二、总结

这次聊天 Demo 已经从一个简单输入输出页面，升级成了一个更接近真实业务的 AI 聊天模块。

目前已经包含：

```text
基础聊天输入
AI 流式回复
真实 SSE 接口
多轮对话上下文
暂停输出
新会话
历史记录持久化
历史会话恢复
暗黑模式
Provider 统一主题管理
ArkTS 严格类型修复
异常数据防崩溃
```

最核心的技术点可以总结成一句话：

```text
UI 层用响应式对象驱动界面，
持久化层用纯数据对象保证序列化稳定，
Controller 负责把 SSE 流式结果逐步写入当前 AI 消息。
```

这次踩坑最多的地方不是 UI，而是状态和数据结构：`@Trace` 能刷新 UI，但不能直接持久化；历史数据可能不完整，所以 UI 不能直接 `.length`；SSE 是异步流式的，所以必须管理当前请求和当前 AI 消息引用；ArkTS 严格模式下，类型必须写清楚。

解决完这些问题后，聊天模块整体稳定了很多，也更接近实际项目里 AI 聊天页面的开发方式。
