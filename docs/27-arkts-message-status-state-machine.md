# 聊天消息的「状态」该怎么存？从一堆 boolean 到一个状态机

> 项目：`MyApplication`（AI 打车对话 demo）
> 目标文件：`chat/src/main/ets/models/MessageStatus.ets`（新建）+ `models/chatModel.ets` + `components/ChatListComp.ets`
> 一句话：把「这条消息现在是什么状态」从**散落的几个 boolean + 往正文里拼字符串**，升级成**一个枚举状态机**。这是本系列状态三部曲的第一篇，专讲数据建模。

---

## 〇、先看一个你每天都在用的场景

打开微信发消息，你会看到三种样子：

- 消息旁边转个**小圈圈** —— 正在发送；
- 圈圈消失 —— 发出去了；
- 变成一个**红色感叹号** —— 没发出去，点一下重发。

这背后其实就是一个问题：**一条消息，要怎么记录它"现在处于哪一步"？**

AI 对话比微信还多两步 —— AI 要"思考"、要"一个字一个字往外蹦"、你还能中途**喊停**。状态更多，记录方式就更容易写乱。这篇就从我 demo 里一段"看着能跑、其实埋雷"的旧代码讲起。

---

## 一、旧写法：一个全局 `isLoading` + 往正文里拼字符串

最早我的消息模型长这样，只有内容，没有"状态"这个概念：

```ts
@ObservedV2
export class ChatMessage {
  @Trace content: string = ''   // 正文
  role: string = ''             // 'user' | 'assistant'
}
```

"正在生成"靠 ViewModel 上一个**全局**布尔：

```ts
@Trace isLoading: boolean = false   // 整个会话共用一个
```

然后所有跟状态有关的事，都用很"土"的方式硬塞：

```ts
// 停止生成时：把"已停止"直接拼到正文后面 😇
stopGeneration(): void {
  if (this.activeAiMessage) {
    const old = this.activeAiMessage.content
    this.activeAiMessage.content = old.length > 0
      ? old + '\n\n[已停止]'      // ← 状态被当成正文写进去了
      : '[已停止]'
  }
  this.vm.isLoading = false
}

// 失败时：把正文整个改成一句错误话术
onError: () => {
  this.activeAiMessage.content = '生成失败，请稍后重试'   // ← 同样是状态混进正文
}
```

能跑。但只要多想一层，问题全是窟窿 👇

| 你想做的事 | 旧写法为什么做不到 |
|---|---|
| 持久化后还原"这条是被停止的" | 存进数据库的只有 `content`，里面混着 `[已停止]`，读回来分不清是 AI 真说了这四个字，还是状态 |
| 给"已停止"单独配个灰色分割线样式 | 它就是正文的一部分，没法单独挑出来加样式 |
| 把界面文案换成英文 / 改措辞 | `[已停止]`、`生成失败...` 散在 Controller 各处，改一个漏一个 |
| 区分"用户消息发送中"和"AI 思考中" | 只有一个全局 `isLoading`，它俩共用，分不开 |
| 同时有"发送中"和"已失败" | `isLoading` 是会话级的，根本不是"某条消息"的状态 |

> 💡 **核心病灶**：状态（meta）和内容（content）是两种东西，被搅在了一起。**正文应该只装 AI 说的话，状态要单独有个字段。**

---

## 二、第一反应：那就多加几个 boolean 呗？

很自然的下一步，是给消息加一排开关，生产里不少代码也是这么写的：

```ts
@ObservedV2
export class ChatMessage {
  @Trace content: string = ''
  @Trace isLoading: boolean = false     // 思考中
  @Trace isStreaming: boolean = false   // 流式输出中
  @Trace isFailed: boolean = false      // 失败了
  @Trace stoppedMessage: string = ''    // 停止提示（非空就显示）
}
```

比第一版强多了 —— 至少状态从正文里分出来了。但它有个隐患，有个专门的名字叫 **布尔陷阱 / 布尔汤（boolean soup）**：

**4 个 boolean = 2⁴ = 16 种组合，但合法的状态其实只有 5、6 种。** 剩下的全是"非法状态"，编译器却拦不住你写出来：

```ts
msg.isLoading = true
msg.isFailed  = true   // 又在思考、又失败了？这是什么状态？🤔
```

```ts
msg.isStreaming = true
msg.isLoading   = true  // 既在思考又在流式？自相矛盾
```

这些组合在类型上完全合法，能编译、能赋值，但语义上是**坏数据**。一旦哪段逻辑漏改一个开关，UI 就会进入一个"谁都没设计过"的中间态 —— 这类 bug 最难查，因为它本不该存在。

> ⚠️ 多 boolean 的本质问题：**它允许你表达"不可能发生"的状态。** 状态越多，非法组合越多，维护时全靠人脑约束"这俩不能同时为 true"，迟早出错。

---

## 三、正解：一个枚举，一次只能是一个状态

一条消息在**任意时刻**只会处于**一个**状态 —— 那就用一个字段、一个枚举来表达它。这在软件设计里有句口号叫 **"让非法状态无法被表示"（make illegal states unrepresentable）**：

```ts
// chat/src/main/ets/models/MessageStatus.ets
export enum MessageStatus {
  SENDING   = 'sending',    // 用户消息：已发出，等待服务端受理
  THINKING  = 'thinking',   // AI：已受理，等首个字（"思考中"）
  STREAMING = 'streaming',  // AI：正在逐字输出
  DONE      = 'done',       // 终态：正常完成
  STOPPED   = 'stopped',    // 终态：用户主动停止
  FAILED    = 'failed',     // 终态：失败（user 可重发 / assistant 可重新生成）
}
```

消息模型也就干净了 —— 一个 `status` 取代一排 boolean：

```ts
@ObservedV2
export class ChatMessage {
  @Trace content: string = ''                          // 只装正文
  role: string = ''
  @Trace status: MessageStatus = MessageStatus.DONE    // 状态独立成字段
}
```

对比一下三版的差距：

| 维度 | ① 全局 isLoading + 拼字符串 | ② 多 boolean | ③ 单一枚举 ✅ |
|---|---|---|---|
| 状态和正文分离 | ❌ 混在一起 | ✅ | ✅ |
| 能否写出非法状态 | —— | ❌ 能（16 选 6） | ✅ 不能，天然互斥 |
| 区分 user / AI 各自状态 | ❌ 共用一个 | ✅ | ✅ |
| 加新状态 | 到处改 if | 再加一个 boolean（组合爆炸） | 枚举里加一个值 |
| `switch` 是否能穷举检查 | —— | ❌ | ✅ 一眼看全 |

> 💡 判断"该用 boolean 还是 enum"的土办法：**这些标志位会不会同时为真？** 会 → 它们是独立维度，用多个 boolean；**互斥（同一时刻只有一个成立）→ 用一个 enum。** 消息状态显然是后者。

---

## 四、状态怎么流转：画出来就清楚了

枚举的另一个好处是，所有"合法的状态迁移"可以画成一张图，照着图写代码不容易漏：

```text
用户消息：
  SENDING ──首个 chunk 到达──► DONE        （送达，AI 开始回）
        └──发不出去 / 服务端报错──► FAILED   （红叹号，可重发）

AI 消息：
  THINKING ──首个 chunk──► STREAMING ──流结束──► DONE      （正常收完）
         │                          ├─用户点停止─► STOPPED  （独立"已停止"条）
         │                          └─中途断网───► FAILED   （留半截，可重新生成）
         └──一个字都没来 / 报错──────────────────► FAILED
```

对照需求，每个状态都有了明确归宿：

| 产品需求 | 落到哪个状态 |
|---|---|
| 用户消息"发送中" | user → `SENDING` |
| AI"正在流式输出" | ai → `THINKING` → `STREAMING` |
| 网络失败 + 重新发送 | user → `FAILED` |
| AI 消息重新生成 | assistant 终态 → 点「重新生成」 |
| 停止后显示独立状态 | ai → `STOPPED` |

一个枚举把五条需求一网打尽。剩下"怎么发请求推进这些状态""失败/重发的编排"是下一篇的事，这篇只聚焦**建模**。

---

## 五、把"停止"做成独立状态，而不是拼进正文

这是这次最想纠正的一个坏习惯。回看旧代码：

```ts
// ❌ 旧：状态拼进正文
this.activeAiMessage.content = old + '\n\n[已停止]'
```

```ts
// ✅ 新：状态归状态，正文归正文
this.activeAiMessage.status = MessageStatus.STOPPED
// content 保持用户停止前已经收到的那部分，一个字不动
```

正文干净了，UI 就能**单独**为"已停止"渲染一条分割线 + 灰字，而不用去正文里抠 `[已停止]` 四个字：

```ts
// ChatListComp.ets —— assistant 气泡内
if (this.msg.status === MessageStatus.STOPPED) {
  Text(ChatText.STOPPED)                                  // '已停止生成'
    .fontSize(12)
    .fontColor(this.theme.textTertiary)
    .padding({ top: 4 })
    .border({ width: { top: 0.5 }, color: this.theme.divider })  // 顶部一条分割线
}
```

> 💡 一个朴素但好用的判断标准：**如果一段文字将来要"单独配样式 / 单独翻译 / 单独存取"，它就不该和正文拼在一个字符串里。** "已停止""生成失败"都属于这一类，它们是 UI 状态，不是对话内容。

顺手把所有界面文案收口到一个常量类，告别魔法字符串散落：

```ts
// chat/src/main/ets/constants/ChatConstants.ets
export class ChatText {
  static readonly THINKING: string = '思考中'
  static readonly STOPPED: string = '已停止生成'
  static readonly RESEND: string = '重新发送'
  static readonly REGENERATE: string = '重新生成'
  // ...
}
```

---

## 六、UI 按状态渲染：ArkUI V2 有个"必须在 build 顶层读"的坑

有了 `status`，气泡就是一个**纯函数**：给定 `status`，渲染对应形态。但 ArkUI V2 这里有个新手必踩的坑 —— **响应式字段（`@Trace`）必须在 `build()` 的"顶层"被读到，依赖才会被追踪到。**

什么叫"顶层"？就是直接写在 `build()` 里的 `if`/表达式中，而**不是**把字段当参数塞进 `@Builder` 函数。后者会让 V2 丢掉依赖，状态变了 UI 不刷新：

```ts
build() {
  Column() {
    // ✅ 直接在 build 里读 this.msg.status，依赖被追踪，状态一变就重渲染
    if (this.msg.status === MessageStatus.THINKING) {
      Row({ space: 8 }) {
        LoadingProgress().width(16).height(16).color(this.theme.primary)
        Text(ChatText.THINKING).fontColor(this.theme.textSecondary)
      }
    } else if (this.msg.content.length > 0) {
      // 流式光标：用一个 Span 拼，仍然不进 content
      Text() {
        Span(this.msg.content)
        Span(this.msg.status === MessageStatus.STREAMING ? '  ▌' : '')
          .fontColor(this.theme.primary)
      }
    }
  }
}
```

> ⚠️ 反例：`MyBuilder(this.msg.status)` 把响应式字段当 `@Builder` 入参传进去 —— V2 收不到依赖，`status` 变了这块 UI 纹丝不动。**记住：结构性的 `if` 分支，直接读字段，别绕一层函数参数。**

注意那个**流式光标 `▌`** 的小技巧：我没有把它拼进 `content`（那样又脏了正文），而是另起一个 `Span`，靠 `status === STREAMING` 决定它是 `'  ▌'` 还是空串。流结束 `status` 变 `DONE`，光标自己就消失了 —— 状态驱动 UI，正文始终干净。

---

## 七、一句话心智模型

```text
正文只装"说了什么"，状态单独一个字段装"现在哪一步"。
互斥的状态 → 一个 enum，别用一堆 boolean（boolean soup 会放进非法组合）。
让非法状态无法被表示：编译器替你挡掉"又在思考又失败"。
"已停止""失败"是 UI 状态不是正文，要能单独配样式 / 翻译 / 存取。
ArkUI V2：响应式字段在 build 顶层读，别塞进 @Builder 参数。
```

## 八、顺口溜

```text
正文状态要分家，别往 content 里硬拼塞；
boolean 多了汤一锅，非法组合挡不住。
一个 enum 管到底，互斥状态它最配；
停止失败独立态，单挑样式随你裁。
V2 刷新有讲究，字段顶层 build 里读；
塞进 Builder 当参数，依赖一丢界面木。
```

---

## 九、参考

- [@ObservedV2 / @Trace（状态管理 V2）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-observedv2-and-trace) —— 本文气泡实时刷新的底层机制
- [@ComponentV2](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-componentV2-V5) / [@Param](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkts-new-param-V5)
- [状态管理总览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-state-management-v2)
- [ArkTS（TS→ArkTS 迁移）：枚举与严格类型](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/typescript-to-arkts-migration-guide)
- 本系列：上一篇 [25-arkts-rdb-chat-persistence](./25-arkts-rdb-chat-persistence.md)，下一篇 [28-arkts-resend-regenerate-idempotency](./28-arkts-resend-regenerate-idempotency.md)（重发 / 重新生成 / 幂等防重）、[29-arkts-message-status-rdb-persistence](./29-arkts-message-status-rdb-persistence.md)（状态入库与历史还原）
