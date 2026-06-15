# 从一次“重新发送 / 重新生成”开始，聊聊流式聊天状态机到底解决了什么问题

最近在整理自己的 HarmonyOS 聊天 Demo，发现聊天页里有一个问题很容易被忽略：

```text
AI 回复失败以后，到底应该让用户点“重新发送”，还是点“重新生成”？
```

这个问题看起来只是一个按钮文案问题，但真正往下想，会发现它其实牵出了整个流式聊天模块的状态设计。

比如：

```text
用户消息什么时候算发送成功？
AI 消息什么时候从“思考中”变成“生成中”？
最后一帧 done 里如果带 error，算成功还是失败？
流式返回一半断了，应该让用户重新发送问题，还是让 AI 重新生成回答？
历史记录恢复时，如果某条消息还停在 STREAMING，应该怎么处理？
```

这些问题如果一开始没有想清楚，代码很容易变成一堆 `if else`、魔法字符串和临时兜底。

所以这次重构，我没有继续在旧逻辑上补判断，而是把聊天消息抽象成了一套更明确的状态机，并且把错误也类型化。

这篇文章就从一个最常见的场景开始，聊聊这次重构到底解决了什么问题。

## 一. 先想一个最简单的需求

假设用户在聊天框里输入：

```text
帮我生成一份日报
```

然后点击发送。

站在用户角度，他只看到两件事：

```text
我的问题发出去了
AI 开始回复了
```

但站在代码角度，这个过程其实至少包含两条消息：

```text
userMessage：用户发出的那条问题
aiMessage：AI 即将生成的那条回复
```

所以正常发送时，代码要先做几件事：

```text
创建用户消息 userMessage，状态为 SENDING
创建 AI 占位消息 aiMessage，状态为 THINKING
生成历史上下文快照 historySnapshot
把这两条消息 push 到 historyMessage
调用 runStream 发起 SSE 流式请求
```

也就是说，用户点一次发送，页面上其实先插入了两条消息。

用户消息负责展示“我刚刚问了什么”。

AI 消息负责接收后续一段段流式返回的内容。

## 二. 最粗暴的方案：用字符串和 boolean 硬判断

一开始最容易想到的写法是：

```text
全局用 isLoading 判断是否正在生成
AI 空内容时显示“AI 思考中...”
失败时把 content 改成“生成失败，请稍后重试”
停止时往正文里拼一个 “[已停止]”
```

这种写法能不能跑？

能。

但问题也很明显。

第一，消息状态不清楚。

同样是 `content` 为空，它可能代表：

```text
AI 正在思考
AI 没有收到任何回复
历史记录里内容丢失
刚创建了占位消息
```

这些情况在 UI 上应该是不一样的，但如果只靠 `content.length === 0` 判断，就很容易混在一起。

第二，失败原因不清楚。

如果直接写：

```ts
aiMessage.content = '生成失败，请稍后重试'
```

那这句话到底代表什么？

```text
断网了？
接口超时了？
服务端返回业务错误？
done 帧里没有任何文本和卡片？
```

用户看到的都是失败，但开发时排查问题完全不是一回事。

第三，UI 逻辑会被文案绑架。

如果代码里到处判断：

```ts
content === '生成失败，请稍后重试'
content.includes('[已停止]')
```

那以后产品说文案要改成“服务开小差了”，逻辑也可能跟着出问题。

这就是魔法字符串的问题：它看起来只是文案，实际上却偷偷承担了状态判断的职责。

## 三. 为什么需要 MessageStatus

这次重构里，我新建了 `MessageStatus.ets`。

核心就是把一条消息可能处于的状态明确列出来：

```ts
export enum MessageStatus {
  SENDING = 'sending',
  THINKING = 'thinking',
  STREAMING = 'streaming',
  DONE = 'done',
  STOPPED = 'stopped',
  FAILED = 'failed',
}
```

这样以后看一条消息，不需要猜它现在是什么情况，直接看 `status` 就行。

用户消息主要有三种状态：

```text
SENDING：用户消息已加入列表，等待服务端受理
DONE：服务端已经受理，这条用户消息发送成功
FAILED：消息没发出去，可以重新发送
```

AI 消息主要有五种状态：

```text
THINKING：请求已受理，等待首个 token
STREAMING：正在流式输出
DONE：正常完成
STOPPED：用户主动停止生成
FAILED：生成失败，可以重新生成
```

这里有一个很关键的问题：

```text
为什么 STREAMING 不是终态？
```

因为 `STREAMING` 只是一个过程。

它后面还会继续变化：

```text
STREAMING -> DONE
STREAMING -> FAILED
STREAMING -> STOPPED
```

真正的终态是：

```text
DONE
STOPPED
FAILED
```

终态的意思是：这条消息不会再自己继续变化了。除非用户手动点击“重新发送”或者“重新生成”，否则它就停在这里。

所以 `MessageStatus.ets` 里还加了一个 `isTerminal`：

```ts
export function isTerminal(status: MessageStatus): boolean {
  return status === MessageStatus.DONE ||
    status === MessageStatus.STOPPED ||
    status === MessageStatus.FAILED
}
```

这个函数在历史记录恢复时很有用。

比如 App 被杀掉之前，某条消息还处于 `STREAMING`。等下次打开 App 时，这条流不可能继续接上。

所以读历史时不能让它继续显示“正在生成”，而应该把中途态统一改成失败态，让用户可以重新操作。

## 四. 为什么还需要 ChatError

有了消息状态以后，还需要解决另一个问题：失败原因。

以前失败可能只是一个文案：

```text
生成失败，请稍后重试
```

但这次重构里，我把错误拆成了类型：

```ts
export enum ChatErrorType {
  NETWORK_ERROR = 'NETWORK_ERROR',
  SERVER_ERROR = 'SERVER_ERROR',
  EMPTY_REPLY = 'EMPTY_REPLY',
}
```

这三个错误分别对应三种情况。

第一种是网络错误：

```text
断网
超时
连接被重置
SSE 请求异常
```

这种通常来自 `onError`。

第二种是服务端业务错误：

```text
SSE 本身正常结束
但是 done 帧里的 meta.error 告诉前端这次业务失败了
```

这种必须在 `onDone` 里处理。

第三种是空回复：

```text
流正常结束
但是既没有文本，也没有卡片
```

这种不能当成功，否则页面上会出现一条空的 AI 回复。

所以这次重构里，错误不再直接写成用户文案，而是先变成 `ChatError`：

```ts
ChatError.network(errMsg)
ChatError.server(meta.error)
ChatError.empty()
```

然后再通过：

```ts
error.toUserHint()
```

映射成用户能看到的提示。

这样做的好处是：

```text
日志里能看到真实错误类型
UI 文案可以集中管理
业务逻辑不用再 match 某一句中文
```

## 五. 为什么 meta.error 必须在 onDone 里处理

这个点一开始很容易想错。

很多人会觉得：

```text
既然失败了，那不就应该走 onError 吗？
```

但 SSE 里不一定是这样。

`onError` 更偏网络层或者请求层错误。

比如：

```text
请求发不出去
连接断了
网络超时
```

但还有一种情况是：

```text
请求正常发出去了
服务端也正常返回了最后一帧 done
只是 done 帧里告诉你：这次业务失败
```

这时候网络是成功的，SSE 也是正常结束的，所以不会走 `onError`。

如果前端只处理 `onError`，就会把这种业务错误误判成成功。

所以 `runStream` 里的 `onDone` 需要先判断：

```ts
if (meta.error) {
  this.finalizeFailure(ChatError.server(meta.error))
  return
}
```

然后再判断是否真的有内容：

```ts
const hasContent = this.activeAiMessage !== null &&
  this.activeAiMessage.content.length > 0

const hasCard = this.activeAiMessage !== null &&
  this.activeAiMessage.card !== null

if (!hasContent && !hasCard) {
  this.finalizeFailure(ChatError.empty())
  return
}
```

也就是说，`done` 不等于成功。

真正成功至少要满足：

```text
没有 meta.error
并且有文本内容或者有卡片数据
```

## 六. runStream 到底统一了什么

这次 `ChatController.ets` 最大的变化，是把三类入口都收口到 `runStream`。

三类入口分别是：

```text
sendMessage：用户正常输入并发送
resendMessage：用户消息失败后重新发送
regenerate：AI 回复失败或停止后重新生成
```

这三个入口看起来不一样，但真正发起 SSE 请求、处理 chunk、处理 done、处理 error 的流程是一样的。

如果每个入口都写一遍流式逻辑，后面一定会出问题。

比如：

```text
sendMessage 处理了 meta.error
resendMessage 忘了处理 meta.error
regenerate 忘了清空 card
某个入口忘了清 currentRequest
某个入口 onDone 和 onError 重复收尾
```

所以更合理的做法是：

```text
三个入口只负责准备现场
runStream 负责统一执行流式流程
```

正常发送时：

```text
读取 inputContent
创建 userMessage，状态 SENDING
创建 aiMessage，状态 THINKING
在 push 新消息前生成历史快照
把两条消息加入 historyMessage
清空输入框
调用 runStream
```

重新发送时：

```text
拿到之前 FAILED 的用户消息
做空值和下标安全检查
复用这条 userMessage
把它改回 SENDING
重新插入一个 AI 占位消息
调用 runStream
```

重新生成时：

```text
拿到 UI 传入的 AI 消息
往前找到最近的一条用户消息作为 prompt
复用这条 AI 气泡
清空 content 和 card
把 AI 状态改回 THINKING
调用 runStream
```

这里最重要的区别是：

```text
重新发送：复用用户消息，重新创建 AI 占位
重新生成：复用 AI 消息，用户消息不重新创建
```

这样就能避免重复气泡。

## 七. 首个 chunk 到底代表什么

流式请求开始后，AI 还没有立刻返回完整内容。

但只要收到了第一个 chunk，就说明一件事：

```text
这条用户消息已经被服务端受理了
```

所以 `onChunk` 里会做两个状态推进：

```text
userMessage: SENDING -> DONE
aiMessage: THINKING -> STREAMING
```

然后把 chunk 追加到 AI 消息：

```ts
this.activeAiMessage.content += (chunk ? chunk : '')
```

这个设计很自然。

用户消息一旦被服务端受理，就不应该继续显示发送中。

AI 一旦开始吐字，就不应该继续显示思考中。

所以首个 chunk 是一个很关键的分界点。

## 八. 失败时为什么要分“重新发送”和“重新生成”

这是这次重构里最容易理解，但也最容易写错的地方。

失败以后，不能一律显示“重试”。

因为失败可能发生在两个不同阶段。

第一种情况：AI 一个字都没返回。

这说明用户消息可能还没有真正完成这一轮请求。

这种情况下，应该把用户消息标记为失败：

```text
userMessage.status = FAILED
```

UI 上显示：

```text
重新发送
```

第二种情况：AI 已经返回了一半。

比如：

```text
今天完成了聊天模块的状态机重构，主要包括...
```

然后网络断了。

这时候用户消息肯定已经被服务端接收了，失败的是 AI 生成过程。

所以应该把用户消息标记为成功：

```text
userMessage.status = DONE
```

然后把 AI 消息标记为失败：

```text
aiMessage.status = FAILED
aiMessage.errorHint = error.toUserHint()
```

UI 上显示：

```text
重新生成
```

这就是“按有没有半截内容分流”的核心。

代码里的判断大概就是：

```ts
const hasPartial = ai !== null &&
  (ai.content.length > 0 || ai.card !== null)
```

如果有半截内容，说明失败发生在 AI 回复阶段。

如果没有半截内容，再根据当前入口是否允许用户重发来决定怎么收尾。

## 九. stopGeneration 为什么不是重新发送

这里也很容易混。

用户点击停止生成时，不是重新发送。

停止只是把当前请求中断掉：

```text
destroy 当前请求
让旧请求回调失效
AI 消息状态改成 STOPPED
用户消息状态改成 DONE
解锁 isLoading
```

也就是说，停止生成不会立刻再次调用 `runStream`。

它只是把当前这轮变成终态：

```text
aiMessage.status = STOPPED
```

如果用户后面想继续让 AI 回答，再点“重新生成”，那才会进入 `regenerate`。

这次重构还有一个细节：不再把 `[已停止]` 拼进正文。

以前可能会这样：

```text
AI 正文内容

[已停止]
```

但这会污染真实回复内容。

现在更合理的做法是：

```text
正文还是正文
停止状态交给 status 表达
UI 根据 STOPPED 渲染“已停止生成”
```

状态和正文分开，后续保存历史也更干净。

## 十. 为什么要加 requestSeq 和 finalized

流式请求还有一个隐蔽问题：回调可能乱序或者重复触发。

比如用户点击停止以后，旧请求可能还有残留回调回来。

如果不处理，旧回调可能继续改 `historyMessage`。

所以这次加了 `requestSeq`。

每发起一轮请求，序号自增：

```text
seq = ++requestSeq
```

回调里先判断：

```text
如果当前 seq 已经过期，就直接 return
```

这样旧请求就不能再污染新状态。

另外还有 `finalized`。

它解决的是另一类问题：

```text
onDone 和 onError 都触发了怎么办？
onDone 里已经失败收尾，后面又来了一个 error 怎么办？
```

所以每轮请求只允许 finalize 一次。

这两个字段看起来不起眼，但它们让流式请求收尾更稳。

## 十一. 为什么序列化要下沉到模型

聊天记录需要持久化。

但 UI 用的 `ChatMessage` 不是普通对象，它里面有：

```text
@ObservedV2
@Trace content
@Trace card
@Trace status
```

这种响应式对象不适合直接存储。

所以项目里分了两套模型：

```text
ChatMessage：UI 层使用，负责响应式刷新
ChatMessagePlain：持久化使用，负责 RDB / JSON 读写
```

以前如果在 Controller 里手写转换，就会变成：

```text
Controller 既要管发送请求
又要管保存会话
还要管每个字段怎么拷贝
```

职责就混在一起了。

所以这次把转换逻辑下沉到模型：

```ts
ChatMessage.fromPlain(...)
message.toPlain(...)
```

这样职责就清楚了：

```text
ChatMessage 自己知道怎么从 plain 恢复
ChatMessage 自己知道怎么转成 plain
ChatSessionController 只负责什么时候读取、什么时候保存
```

还有一个很重要的点：`fromPlain` 里会做中途态归一化。

比如历史记录里读到：

```text
SENDING
THINKING
STREAMING
```

这些状态在 App 重启后都不可能继续自动流转。

所以应该统一改成：

```text
FAILED
```

这样用户打开历史记录时，不会看到一条永远转圈的消息。

## 十二. 为什么要删除 ChatPersist.ets

项目之前有一套 Preferences 版本的聊天持久化。

后来已经切到 RDB，也就是 `ChatRdb.ets`。

这个时候旧的 `ChatPersist.ets` 如果还留着，就会造成一种错觉：

```text
项目里好像有两套聊天记录存储
到底该改 Preferences 还是 RDB？
历史记录到底从哪里读？
删除逻辑到底在哪一套？
```

所以删除死代码本身也是重构的一部分。

它的意义不是少一个文件，而是减少误导。

现在项目里只保留一套明确的持久化方案：

```text
ChatRdb 负责聊天会话和消息落库
ChatSessionController 负责调度读写
ChatMessage.fromPlain / toPlain 负责模型转换
```

这条链路比之前清楚很多。

## 十三. 录屏时应该展示什么

这次功能不太适合只截图，因为状态变化是动态的。

更建议录一个 1 分钟左右的视频，按下面顺序展示：

```text
1. 正常发送一条消息
2. 展示“思考中”变成流式输出
3. 等最后一帧完成，消息进入 DONE
4. 模拟断网或服务端错误，展示用户消息 FAILED
5. 点击“重新发送”
6. 再模拟 AI 已经输出一半后失败，展示 AI 消息 FAILED
7. 点击“重新生成”
8. 展示停止生成后出现“已停止生成”
9. 退出再进入历史记录，确认历史消息恢复正常
```

录屏时可以重点口播这几句话：

```text
这次不是单纯加了一个重试按钮，而是把聊天消息拆成了状态机。
用户消息失败和 AI 生成失败不是一回事，所以 UI 上分别对应重新发送和重新生成。
done 帧不一定代表成功，因为 done 里也可能带 meta.error。
历史记录恢复时，中途态不能继续转圈，所以会归一化成 FAILED。
```

这样别人看视频时，不只是看到按钮能点，而是能理解你为什么这么设计。

## 十四. UI 样式可以怎么顺手优化

这个功能本身偏逻辑，但如果想让演示更直观，可以给状态加一点轻量 UI。

比如 `THINKING` 状态可以做一个小的动态 loading 图标。

如果项目里想做得更有辨识度，可以做一个类似“大风车”的旋转图标：

```text
AI 思考中：小风车慢速旋转
STREAMING：风车旋转 + 文本逐段出现
FAILED：风车停止，显示错误提示和操作按钮
STOPPED：显示一条“已停止生成”的分割提示
```

背景色也可以稍微区分状态：

```text
THINKING：浅蓝灰背景，表达等待
STREAMING：普通聊天背景，表达正在输出
FAILED：浅红或浅橙提示，不要太刺眼
STOPPED：浅灰分割线，表达用户主动中断
DONE：正常展示，不突出状态
```

按钮也可以按语义区分：

```text
重新发送：放在用户气泡旁边
重新生成：放在 AI 回复下方
停止生成：放在输入框发送按钮位置
```

这样 UI 和状态机是对应的。

不是为了炫技加动效，而是让用户一眼知道：

```text
现在到底是正在想、正在生成、失败了、还是我主动停了
```

## 十五. 总结

这次重构最核心的收获，不是多写了几个文件，而是把原来模糊的聊天流程拆清楚了。

以前可能是：

```text
靠 isLoading 判断生成中
靠 content 为空判断思考中
靠某句中文判断失败
靠拼接 [已停止] 表示停止
```

现在变成：

```text
MessageStatus 表达消息状态
ChatError 表达失败原因
ChatConstants 收口角色和文案
runStream 统一处理 SSE 生命周期
fromPlain / toPlain 负责模型转换
ChatRdb 负责唯一的持久化实现
```

整个聊天流程也更清楚了：

```text
用户发送
↓
userMessage = SENDING
aiMessage = THINKING
↓
首个 chunk 返回
↓
userMessage = DONE
aiMessage = STREAMING
↓
done 帧成功
↓
aiMessage = DONE
```

失败时也不再一刀切：

```text
AI 没有半截内容：用户消息 FAILED，显示重新发送
AI 已有半截内容：AI 消息 FAILED，显示重新生成
用户主动停止：AI 消息 STOPPED，后续可重新生成
```

所以状态机不是为了把代码写复杂。

它恰恰是为了解决一个真实问题：

```text
当聊天流程里出现发送中、思考中、生成中、完成、失败、停止这些状态时，
我们不能再靠字符串和临时判断猜消息处于哪里。
```

把状态、错误、文案、序列化和请求流程拆清楚以后，代码反而更容易维护。

后面再加更多卡片类型、更多错误类型、更多重试入口，也不会乱成一团。

这也是我这次最大的体会：

```text
流式聊天最难的不是把 chunk 追加到页面上，
而是把每一条消息在每个时刻到底处于什么状态讲清楚。
```
