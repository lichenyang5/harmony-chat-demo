# 失败重发、AI 重新生成，以及"同一个请求别写两遍"

> 项目：`MyApplication`（AI 打车对话 demo）
> 目标文件：`chat/src/main/ets/controller/ChatController.ets`（重写）+ `models/ChatError.ets`（新建）
> 一句话：上一篇把消息状态做成了枚举状态机，这篇讲**谁来推进这些状态** —— Controller 怎么编排"发送 / 重发 / 重新生成 / 停止"，以及最容易被忽略、面试最爱问的一点：**怎么保证同一个请求不会把数据写两遍（幂等）。**

---

## 〇、先说为什么这部分最练"功力"

发消息谁都会写：push 一条、发请求、回调里拼内容。但真实世界是有**时序**和**并发**的：

- 用户点了「停止」，可半秒前发出的网络包还在路上，**回调照样会回来** —— 它该不该再改界面？
- 网络抖一下，传输层报了 `onError`，紧接着 socket 关闭又触发了一次"流结束" `onDone` —— **同一轮被收尾两次**会怎样？
- 用户手一抖，「重新发送」连点了三下 —— 会不会冒出**三条**一样的消息？

这些都属于"**同一个逻辑请求，产生了多次写入**"。它们不会在你本地点一两下时暴露，但上线后就是偶现的"消息重复""幽灵气泡""停了还在动"。把这层处理干净，才是 Controller 这层真正的价值。

---

## 一、三个入口，一个核心：runStream

「首次发送」「失败重发」「重新生成」表面是三件事，骨架其实一样：**准备好一条 user 消息和一条 AI 气泡 → 发流 → 回调推进状态**。区别只在前半段怎么准备。所以我抽了一个私有核心，三个公开入口共用它：

```ts
private runStream(
  userMsg: ChatMessage,   // 本轮用户消息（它的 content 就是要发的内容）
  aiMsg: ChatMessage,     // 本轮 AI 气泡（流式内容累积到这里）
  history: ChatHistoryItem[],   // 上下文（不含本轮）
  allowUserResend: boolean      // 失败且 AI 无内容时，是否标用户消息可重发
): void { /* 发 SSE + 接管回调，见后文 */ }
```

三个入口各自只管"准备"：

```ts
// ① 首次发送：新建 user(SENDING) + ai(THINKING)，都 push 进去
sendMessage(): void {
  const userMessage = this.createMessage(ChatRole.USER, content, MessageStatus.SENDING)
  const aiMessage   = this.createMessage(ChatRole.ASSISTANT, '', MessageStatus.THINKING)
  const history = this.buildHistorySnapshot(this.vm.historyMessage.length) // push 前取快照
  this.vm.historyMessage.push(userMessage)
  this.vm.historyMessage.push(aiMessage)
  this.runStream(userMessage, aiMessage, history, true)
}
```

> 💡 注意 `history` 必须在 **push 之前**取 —— 否则会把本轮那条空的 AI 占位也算进上下文发给后端。这种"先拍快照再改数据"的顺序，是流式场景里很容易踩反的小坑。

---

## 二、失败其实有两种，UI 给的出口也不同

很多人把"失败"当成一个状态就完了。但从用户视角，失败分两种，**该给的补救按钮完全不同**：

| 失败时机 | AI 收到内容了吗 | 语义 | 给用户的出口 |
|---|---|---|---|
| 请求就没发出去 / 服务端直接报错 | ❌ 一个字都没有 | "你这句话没送到" | **用户气泡**标红叹号 → 重新发送 |
| 流到一半断网 | ✅ 已经收了半截 | "话送到了，AI 答了一半断了" | **AI 气泡**标失败 → 重新生成 |

所以失败收尾要按"AI 有没有内容"分流：

```ts
private finalizeFailure(error: ChatError): void {
  const ai = this.activeAiMessage
  const hasPartial = ai !== null && (ai.content.length > 0 || ai.card !== null)

  if (hasPartial && ai !== null) {
    // 有半截内容：用户消息算送达，AI 气泡标 FAILED（可重新生成）
    if (this.activeUserMessage) this.activeUserMessage.status = MessageStatus.DONE
    ai.status = MessageStatus.FAILED
    ai.errorHint = error.toUserHint()
  } else if (this.allowUserResend) {
    // 一个字没来 + 首发/重发场景：标用户消息可重发，移除那条空 AI 占位（不留半截气泡）
    if (this.activeUserMessage) {
      this.activeUserMessage.status = MessageStatus.FAILED
      this.activeUserMessage.errorHint = error.toUserHint()
    }
    if (ai !== null) this.removeMessage(ai)
  } else {
    // 一个字没来 + 重新生成场景：保留 AI 气泡为 FAILED（别反过来标用户失败）
    if (ai !== null) { ai.status = MessageStatus.FAILED; ai.errorHint = error.toUserHint() }
  }
  this.finishRequest()
}
```

这样"重新发送"只会出现在**用户**气泡、"重新生成"只会出现在**AI**气泡，语义不打架。

### 顺便：用类型化错误替掉魔法字符串

旧代码失败时把正文改成 `'生成失败，请稍后重试'`，想区分原因只能去 `indexOf('网络')` 猜字符串。换成一个小小的类型化错误对象，原因变成可枚举、可分支：

```ts
// chat/src/main/ets/models/ChatError.ets
export enum ChatErrorType {
  NETWORK_ERROR = 'NETWORK_ERROR',  // 传输层失败（连不上 / 超时）
  SERVER_ERROR  = 'SERVER_ERROR',   // done 帧里带了 error
  EMPTY_REPLY   = 'EMPTY_REPLY',    // 流结束但一个字都没收到
}
export class ChatError {
  type: ChatErrorType
  message: string
  constructor(type: ChatErrorType, message: string = '') {
    this.type = type           // ArkTS 不支持 TS 的构造参数属性(public type)，得显式声明字段
    this.message = message
  }
  static network(message: string = ''): ChatError { return new ChatError(ChatErrorType.NETWORK_ERROR, message) }
  static server(message: string = ''): ChatError { return new ChatError(ChatErrorType.SERVER_ERROR, message) }
  static empty(): ChatError { return new ChatError(ChatErrorType.EMPTY_REPLY) }
  toUserHint(): string { /* 按 type 映射到 ChatText 文案 */ return '' }
}
```

这还顺手修了一个旧 bug：以前 `onDone` 压根没看服务端的 `error` 字段，后端在结束帧里报了错，客户端却当成功处理。现在：

```ts
onDone: (meta) => {
  if (meta.error) { this.finalizeFailure(ChatError.server(meta.error)); return }  // ← 补上
  // ...正常成功路径
}
```

---

## 三、重头戏：怎么保证"同一个请求不写两遍"

这是本篇的核心。我用**三道**互相独立的护栏，分别堵住三类重复写入。

### 护栏 1：`requestSeq` —— 让过期请求的回调"自动失效"

给每一次发起编一个号。回调在闭包里**记住自己出生时的号**；只要当前号变了（被停止、或开了新一轮），旧回调一律罢工：

```ts
private requestSeq: number = 0

private runStream(...): void {
  const seq = ++this.requestSeq      // 本轮领一个号
  // ...
  {
    onChunk: (chunk) => {
      if (this.isStale(seq)) return  // 号对不上 = 我已过期，啥也不干
      // ...正常累积
    },
    // onDone / onError 同理，开头都先 isStale(seq) 判一下
  }
}

private isStale(seq: number): boolean {
  return seq !== this.requestSeq     // 当前号已经不是我了
}
```

**停止生成**就是靠"把号 +1"让在途请求集体失效：

```ts
stopGeneration(): void {
  if (!this.vm.isLoading) return
  this.requestSeq++                  // ← 关键：旧请求的 seq 立刻过期
  if (this.currentRequest) {
    try { this.currentRequest.destroy() } catch (_) {}
    this.currentRequest = null
  }
  if (this.activeAiMessage) this.activeAiMessage.status = MessageStatus.STOPPED  // 独立停止态
  if (this.activeUserMessage) this.activeUserMessage.status = MessageStatus.DONE
  this.finishRequest()
}
```

> 🎬 **配合上一篇的场景**：用户点停止 → `requestSeq` 从 7 变 8 → 半秒后那个迟到的 `onChunk` 回来，它记得自己是 7，`isStale(7)` 命中 → 直接 return，**不会再往已经"已停止"的气泡里追加内容**。这就是"停了就真的停了"，而不是"停了还在动"。

### 护栏 2：`finalized` —— 一轮只许收尾一次

`onDone` 和 `onError` 都可能触发"收尾"。网络异常时，传输层先 `onError`，socket 关闭可能又补一个 `onDone` —— 同一轮被收尾两次，就会双重写状态、双重落库。一个布尔锁解决：

```ts
private finalized: boolean = true   // 初始 true：没有在途请求

private runStream(...): void {
  this.finalized = false            // 开工
  // ...
  onDone:  (meta) => { if (this.isStale(seq) || this.finalized) return; /* 收尾 */ },
  onError: (msg)  => { if (this.isStale(seq) || this.finalized) return; /* 收尾 */ },
}

private finishRequest(): void {
  this.finalized = true             // 收尾，后到的另一个回调进不来
  this.vm.isLoading = false
  this.activeAiMessage = null
  this.activeUserMessage = null
  this.currentRequest = null
}
```

> 💡 `requestSeq` 防的是**跨轮**的串台（旧轮回调污染新轮）；`finalized` 防的是**同一轮内**的重复收尾。两者维度不同，缺一不可。

### 护栏 3：复用消息对象 —— 从源头不产生重复气泡

「重发」和「重新生成」最容易写出的 bug，就是**又 push 了一条新消息**，于是界面冒出重复气泡、落库也多一行。正解是**复用已经存在的那条对象**：

```ts
// 重新发送：复用同一条 user 对象，绝不 push 新的
resendMessage(target: ChatMessage): void {
  if (this.vm.isLoading || target.role !== ChatRole.USER) return  // 连点防护：在途就不睬
  const idx = this.vm.historyMessage.indexOf(target)
  target.status = MessageStatus.SENDING   // 把它本身重置回"发送中"
  target.errorHint = ''
  const aiMessage = this.createMessage(ChatRole.ASSISTANT, '', MessageStatus.THINKING)
  this.vm.historyMessage.splice(idx + 1, 0, aiMessage)   // 只补一条新 AI 占位
  this.runStream(target, aiMessage, this.buildHistorySnapshot(idx), true)
}
```

```ts
// 重新生成：复用同一条 AI 气泡，清空内容重来，不新增气泡
regenerate(target: ChatMessage): void {
  if (this.vm.isLoading || target.role !== ChatRole.ASSISTANT) return
  // ...向上找到它对应的用户 prompt...
  target.content = ''
  target.card = null
  target.status = MessageStatus.THINKING   // 同一条气泡，原地重生
  this.runStream(promptMsg, target, history, false)
}
```

`if (this.vm.isLoading) return` 这一句还顺手挡了**连点**：第一次点已经把 `isLoading` 置真，后续连点直接被弹回，不会并发出第二、第三个请求。

---

## 四、三道护栏各自防住什么

| 护栏 | 防的是 | 典型触发场景 |
|---|---|---|
| `requestSeq` 失效 | 跨轮串台：过期请求的回调污染新一轮 | 点了停止/重发后，上一个请求的迟到回调还在回来 |
| `finalized` 一次性 | 同轮重复收尾：onError 和 onDone 都来 | 网络抖动，传输层报错 + 流结束各触发一次 |
| 复用对象 + isLoading 闸 | 重复气泡 / 并发请求 | 「重发」「重新生成」连点 |

三者叠起来，才凑齐"同一个请求只写一次"。少任何一道，都是一类偶现 bug 的温床。

---

## 五、一句话心智模型

```text
三个入口（发送/重发/重新生成）共用一个 runStream，区别只在"怎么准备消息"。
失败分两种：没送到 → 标用户可重发；答一半断了 → 标 AI 可重新生成。
幂等三件套：
  · requestSeq —— 过号即作废，防跨轮串台（停止/新一轮让旧回调失效）；
  · finalized  —— 一轮只收尾一次，防 onError+onDone 双写；
  · 复用对象 + isLoading 闸 —— 不 push 重复气泡、不并发重复请求。
错误别用字符串，枚举化 ChatError，顺手消费服务端 error 字段。
```

## 六、顺口溜

```text
一核三入口，runStream 共用走；
失败看内容，没来标用户、半截让 AI 兜。
停止号一跳，旧回调全跑掉（requestSeq）；
收尾上把锁，双回调进不了（finalized）。
重发不新建，复用对象别多添；
loading 当闸门，连点并发全拦严。
```

---

## 七、参考

- [@Monitor（监听状态变化）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-monitor) —— 下一篇用它在流式结束时触发落库
- [@ObservedV2 / @Trace](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-observedv2-and-trace) —— `historyMessage` 数组增删驱动列表刷新
- [Network Kit（http 流式请求与 destroy 中断）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http)
- 本系列：上一篇 [27-arkts-message-status-state-machine](./27-arkts-message-status-state-machine.md)（状态机建模），下一篇 [29-arkts-message-status-rdb-persistence](./29-arkts-message-status-rdb-persistence.md)（状态入库与历史还原）
