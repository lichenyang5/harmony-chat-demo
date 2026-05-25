# 鸿蒙聊天 Demo 练习 06：AI 思考气泡与 MVVM + Controller 结构重构

## 一、本次分支

```bash
feature/chat-mvvm-refactor
```

如果前面单独做过 AI 思考气泡，也可以对应：

```bash
feature/ai-thinking-bubble
```

本次最终建议以结构重构分支为主，因为 AI 思考气泡已经不是单纯 UI 小功能，而是被纳入了聊天控制器的业务流程中。

## 二、本次目标

本次在原有鸿蒙聊天 Demo 的基础上，完成两个重点内容：

1. 新增 AI 思考气泡功能。
2. 重构聊天页面代码结构，拆分成 View + ViewModel + Controller。

前面 Demo 已经完成了：

1. 基础聊天页面。
2. 消息发送和列表渲染。
3. 自动滚动到底部。
4. 接入 Next.js 后端聊天接口。
5. 聊天历史本地缓存。
6. 登录页和登录态保存。
7. 退出登录。

但是随着功能不断增加，`Setting.ets` 中的逻辑越来越多：

```txt
页面 UI
输入框状态
登录态初始化
聊天历史缓存
发送消息
后端请求
AI 思考气泡定时器
清空聊天
退出登录
保存缓存
滚动到底部
```

如果继续把所有逻辑写在页面里，后面再加会话列表、数据库、多用户历史、请求拦截器时，页面会越来越难维护。

所以本次目标是：

```txt
先完成 AI 思考气泡体验优化
再把页面里的状态和业务流程拆出去
让 Setting.ets 回到 View 的职责
```

最终结构：

```txt
Setting.ets
↓
ChatViewModel.ets
↓
ChatController.ets
↓
ChatApi.ets / ChatStorage.ets / AuthStorage.ets
```

## 三、涉及文件

本次主要新增文件：

```txt
entry/src/main/ets/viewmodels/ChatViewModel.ets
entry/src/main/ets/controllers/ChatController.ets
```

本次主要修改文件：

```txt
entry/src/main/ets/pages/Setting.ets
```

已有依赖文件：

```txt
entry/src/main/ets/api/ChatApi.ets
entry/src/main/ets/models/ChatModel.ets
entry/src/main/ets/models/AuthModel.ets
entry/src/main/ets/utils/ChatStorage.ets
entry/src/main/ets/utils/AuthStorage.ets
entry/src/main/ets/stores/AuthStore.ets
entry/src/main/ets/stores/TabState.ets
entry/src/main/ets/constants/RouteConstants.ets
```

文档文件：

```txt
docs/06-ai-thinking-bubble-mvvm-refactor.md
```

## 四、为什么要做 AI 思考气泡

之前的聊天流程是：

```txt
用户输入内容
↓
点击发送
↓
右侧展示用户消息
↓
等待后端返回
↓
左侧展示 assistant 回复
```

这个流程功能上没问题，但体验上有一个问题：

```txt
后端返回之前，聊天区域没有明显反馈。
```

虽然按钮会显示“发送中”，但是用户关注点通常在消息列表区域。

所以本次新增 AI 思考气泡：

```txt
用户发送消息
↓
立即展示用户消息
↓
左侧插入一条 assistant 临时气泡
↓
气泡文案轮播：
  AI 正在思考中...
  正在整理上下文...
  正在生成回复...
  马上就好...
↓
后端返回后，用真实 assistant 回复替换临时气泡
```

这样页面反馈更像真实 AI 聊天产品。

## 五、AI 思考气泡的最终效果

最终效果：

```txt
用户：你好

AI：AI 正在思考中...
AI：正在整理上下文...
AI：正在生成回复...
AI：马上就好...

AI：这是 Next.js 后端返回的模拟回复：你好
```

其中前面几句不是多条历史消息，而是同一个临时气泡的内容不断变化。

后端返回后：

```txt
删除临时气泡
追加真实 assistant 回复
保存聊天历史
```

## 六、AI 思考气泡的核心设计

本次 AI 思考气泡有几个关键点：

1. 思考气泡是一条临时 assistant 消息。
2. 思考气泡不保存到本地历史缓存。
3. 思考气泡通过定时器轮播文案。
4. 后端返回太快时，至少展示 2 秒。
5. 后端返回成功时，替换成真实 assistant 回复。
6. 后端请求失败时，替换成错误提示。
7. 页面退出或清空聊天时，需要停止定时器。

核心状态：

```ts
private thinkingTimer: number = -1

private readonly minThinkingDuration: number = 2000

private readonly thinkingInterval: number = 600

private readonly thinkingTexts: string[] = [
  'AI 正在思考中...',
  '正在整理上下文...',
  '正在生成回复...',
  '马上就好...'
]
```

## 七、为什么思考气泡不保存到本地缓存

上一节已经做了聊天历史缓存，发送消息后会把 `chatList` 保存到 `Preferences`。

但是 AI 思考气泡不应该保存。

原因是：

```txt
AI 正在思考中...
```

这不是一条真实消息，而是一个临时 UI 状态。

如果保存进去，可能会出现：

```txt
关闭 App
重新打开 App
历史记录里出现一条永远停留在“AI 正在思考中...”的消息
```

所以本次的缓存策略是：

```txt
用户消息：保存
AI 思考气泡：不保存
真实 assistant 回复：保存
错误提示：保存
```

也就是说，临时气泡只存在于运行时页面状态里，不进入本地持久化数据。

## 八、为什么要至少展示 2 秒

如果后端返回很快，比如 200ms 就返回，思考气泡会一闪而过，用户几乎看不到。

为了让用户明确感知到 AI 正在处理，本次设置了最小展示时间：

```ts
private readonly minThinkingDuration: number = 2000
```

核心逻辑：

```ts
const elapsed: number = Date.now() - thinkingStartTime

if (elapsed < this.minThinkingDuration) {
  await this.wait(this.minThinkingDuration - elapsed)
}
```

含义是：

```txt
如果后端 200ms 返回，就再等 1800ms
如果后端 3000ms 返回，就不额外等待
```

这样既保证了体验，也不会在后端已经很慢时继续强行拖延。

## 九、轮播不生效的问题

开发时遇到了一个问题：

```txt
页面只显示“AI 正在思考中...”2 秒
没有显示后面的轮播文案
2 秒后直接被后端回复替换
```

一开始以为是 `setInterval` 没生效，但实际问题在 `ForEach` 的 key。

原来写法：

```ts
ForEach(this.chatList, (item: ChatMessage) => {
  // ...
}, (item: ChatMessage) => `${item.id}`)
```

思考气泡轮播时，只是修改同一条消息的 `content`：

```txt
AI 正在思考中...
正在整理上下文...
正在生成回复...
马上就好...
```

但是这条消息的 `id` 一直不变。

所以 ArkUI 可能会复用原来的 `ListItem`，导致 UI 没有明显刷新。

## 十、轮播问题的解决方式

解决方式是：普通消息仍然用 `id` 作为 key，思考气泡额外把 `content` 拼进去。

```ts
getMessageKey(item: ChatMessage): string {
  if (item.id === this.viewModel.thinkingMessageId) {
    return `${item.id}-${item.content}`
  }

  return `${item.id}`
}
```

这样思考气泡的 key 会随着文案变化：

```txt
123-AI 正在思考中...
123-正在整理上下文...
123-正在生成回复...
123-马上就好...
```

ArkUI 就会重新构建这条临时气泡，从而看到轮播效果。

这个问题也说明：

```txt
列表渲染时 key 不只是唯一标识，还会影响组件复用和刷新。
```

## 十一、为什么要开始重构代码结构

做完登录、本地缓存、AI 思考气泡后，`Setting.ets` 已经承担了太多职责。

之前的页面大概同时负责：

```txt
UI 展示
输入框状态
登录态读取
AuthStorage 操作
ChatStorage 操作
发送消息
请求后端
思考气泡轮播
错误处理
缓存保存
退出登录
清空聊天
滚动到底部
```

这已经不再是一个单纯页面。

如果继续往里面加功能，比如：

```txt
会话列表
消息分页
数据库历史消息
用户信息
请求拦截器
多平台 Provider
SSE 流式回复
```

页面会变得非常难维护。

所以本次参考公司项目的分层思想，把代码拆成：

```txt
View
ViewModel
Controller
Api
Storage
Store
```

## 十二、重构前后的结构对比

### 重构前

```txt
Setting.ets
  ├── 页面 UI
  ├── 输入框状态
  ├── chatList
  ├── conversationId
  ├── isSending
  ├── isAuthReady
  ├── thinkingTimer
  ├── thinkingTexts
  ├── initAuth
  ├── loadChatCache
  ├── saveChatCache
  ├── sendMessage
  ├── startThinkingBubble
  ├── updateThinkingBubble
  ├── replaceThinkingBubble
  ├── clearChatHistory
  ├── logout
  └── scrollToBottom
```

所有东西都在页面里。

### 重构后

```txt
pages/Setting.ets
  只负责 UI、生命周期、路由跳转、滚动到底部

viewmodels/ChatViewModel.ets
  负责保存页面状态

controllers/ChatController.ets
  负责编排聊天业务流程

api/ChatApi.ets
  负责请求后端聊天接口

utils/ChatStorage.ets
  负责聊天历史本地缓存

utils/AuthStorage.ets
  负责登录态本地缓存

stores/AuthStore.ets
  负责全局登录状态
```

重构后的核心变化是：

```txt
页面不再直接处理所有业务细节
```

## 十三、新增 ChatViewModel

文件：

```txt
entry/src/main/ets/viewmodels/ChatViewModel.ets
```

`ChatViewModel` 负责保存聊天页面状态。

主要状态包括：

```txt
inputValue：输入框内容
chatList：消息列表
isSending：是否正在发送
conversationId：当前会话 ID
isAuthReady：登录态是否初始化完成
token：登录 token
userInfo：当前用户信息
thinkingMessageId：当前思考气泡 ID
thinkingTextIndex：当前思考文案索引
```

核心代码：

```ts
import { ChatMessage } from '../models/ChatModel'
import { UserInfo } from '../models/AuthModel'

@ObservedV2
export class ChatViewModel {
  @Trace inputValue: string = ''
  @Trace chatList: ChatMessage[] = []
  @Trace isSending: boolean = false
  @Trace conversationId: number = 0
  @Trace isAuthReady: boolean = false

  @Trace token: string = ''
  @Trace userInfo: UserInfo | null = null

  @Trace thinkingMessageId: number = 0
  @Trace thinkingTextIndex: number = 0

  setInputValue(value: string): void {
    this.inputValue = value
  }

  setAuth(token: string, userInfo: UserInfo): void {
    this.token = token
    this.userInfo = userInfo
    this.isAuthReady = true
  }

  clearAuth(): void {
    this.token = ''
    this.userInfo = null
    this.isAuthReady = false
  }

  setChatCache(conversationId: number, chatList: ChatMessage[]): void {
    this.conversationId = conversationId
    this.chatList = chatList
  }

  appendMessage(message: ChatMessage): void {
    this.chatList = this.chatList.concat([message])
  }

  appendMessages(messages: ChatMessage[]): void {
    this.chatList = this.chatList.concat(messages)
  }

  replaceChatList(chatList: ChatMessage[]): void {
    this.chatList = chatList
  }

  clearChat(): void {
    this.chatList = []
    this.conversationId = 0
    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
  }

  setSending(value: boolean): void {
    this.isSending = value
  }

  setConversationId(conversationId: number): void {
    this.conversationId = conversationId
  }

  startThinking(thinkingMessageId: number): void {
    this.thinkingMessageId = thinkingMessageId
    this.thinkingTextIndex = 0
  }

  updateThinkingIndex(index: number): void {
    this.thinkingTextIndex = index
  }

  clearThinking(): void {
    this.thinkingMessageId = 0
    this.thinkingTextIndex = 0
  }
}
```

## 十四、ChatViewModel 的职责

`ChatViewModel` 不请求接口，不读写缓存，不跳转页面。

它只做一件事：

```txt
保存和修改页面状态
```

也就是说：

```txt
ViewModel 不关心数据从哪里来
ViewModel 只负责让 View 有状态可读
```

页面只需要读取：

```ts
this.viewModel.chatList
this.viewModel.inputValue
this.viewModel.isSending
this.viewModel.userInfo
```

Controller 只需要调用：

```ts
this.viewModel.appendMessage(message)
this.viewModel.setSending(true)
this.viewModel.setConversationId(id)
```

这样页面和业务流程都不直接操作一堆零散状态。

## 十五、新增 ChatController

文件：

```txt
entry/src/main/ets/controllers/ChatController.ets
```

`ChatController` 负责聊天业务流程编排。

主要能力包括：

```txt
初始化登录态
读取聊天缓存
保存聊天缓存
清空聊天记录
退出登录
发送消息
启动 AI 思考气泡
更新 AI 思考气泡
替换 AI 思考气泡
停止定时器
生成 ForEach key
释放资源
```

可以理解为：

```txt
View 负责展示
ViewModel 负责状态
Controller 负责流程
```

## 十六、ChatController 发送消息流程

重构后，发送消息逻辑从 `Setting.ets` 移到了 `ChatController.ets`。

核心流程仍然不变：

```txt
读取输入框内容
↓
校验空内容 / 发送中 / 未登录
↓
设置 isSending = true
↓
清空输入框
↓
创建用户消息
↓
追加到 ViewModel.chatList
↓
保存聊天缓存
↓
启动 AI 思考气泡
↓
调用 sendChatMessage
↓
后端返回后判断最小展示时间
↓
返回成功：替换成 assistant 回复
↓
返回失败：替换成失败提示
↓
请求异常：替换成错误提示
↓
保存聊天缓存
↓
设置 isSending = false
```

这个流程从页面里抽离出来后，`Setting.ets` 就不需要知道每一步细节。

页面只需要调用：

```ts
this.chatController.sendMessage(
  context,
  () => {
    this.scrollToBottom()
  }
)
```

## 十七、为什么 Controller 里需要回调 scrollToBottom

`scrollToBottom` 仍然留在 `Setting.ets`。

原因是：

```txt
滚动列表属于 UI 行为
Scroller 是页面组件相关对象
Controller 不应该直接持有 Scroller
```

所以 Controller 不直接调用 `this.listScroller.scrollToIndex`。

而是通过回调通知页面：

```ts
type VoidCallback = () => void
```

调用时：

```ts
this.chatController.sendMessage(
  context,
  () => {
    this.scrollToBottom()
  }
)
```

这样分层更合理：

```txt
Controller 知道什么时候需要滚动
View 知道怎么滚动
```

## 十八、重构后的 Setting 页面职责

重构后 `Setting.ets` 只保留这些内容：

```txt
创建 Scroller
创建 ChatViewModel
创建 ChatController
aboutToAppear 生命周期
aboutToDisappear 生命周期
Header UI
MessageList UI
InputBar UI
scrollToBottom
路由跳转回调
```

它不再直接处理：

```txt
AuthStorage.getAuthCache
ChatStorage.getChatCache
sendChatMessage
thinkingTimer
setInterval
JSON 缓存保存
```

这就是 View 应该有的职责。

## 十九、重构后的 Setting.ets 调用方式

页面初始化：

```ts
this.chatController.initAuth(
  context,
  () => {
    HMRouterMgr.replace({
      pageUrl: RouteConstants.LOGIN
    })
  },
  () => {
    this.scrollToBottom()
  }
)
```

发送消息：

```ts
this.chatController.sendMessage(
  context,
  () => {
    this.scrollToBottom()
  }
)
```

清空聊天：

```ts
this.chatController.clearChatHistory(context)
```

退出登录：

```ts
this.chatController.logout(
  context,
  () => {
    HMRouterMgr.replace({
      pageUrl: RouteConstants.LOGIN
    })
  }
)
```

获取列表 key：

```ts
this.chatController.getMessageKey(item)
```

这说明页面变成了：

```txt
只负责调用，不负责实现业务细节
```

## 二十、和公司项目的对应关系

公司项目中的聊天模块大致是：

```txt
AgentChatComp
↓
ChatViewModel
↓
ChatController
↓
CozeProvider
↓
HttpClient
```

本次 Demo 重构后变成：

```txt
Setting.ets
↓
ChatViewModel
↓
ChatController
↓
ChatApi
↓
Next.js /api/chat
```

两者对应关系：

| 公司项目 | 当前 Demo |
|---|---|
| AgentChatComp | Setting.ets |
| ChatViewModel | ChatViewModel.ets |
| ChatController | ChatController.ets |
| CozeProvider | ChatApi.ets 暂时代替 |
| HttpClient | ChatApi 内部的 http.createHttp |

当前 Demo 还没有单独拆出 Provider 和通用 HttpClient，所以目前还只是简化版。

后续可以继续升级为：

```txt
Setting.ets
↓
ChatViewModel
↓
ChatController
↓
ChatProvider
↓
Request
↓
Next.js 后端
```

这样就更接近公司项目的结构。

## 二十一、本次重构带来的好处

### 1. 页面变轻

`Setting.ets` 不再堆大量业务逻辑，后续维护更容易。

### 2. 状态集中

所有聊天页面状态都在 `ChatViewModel` 中，状态来源更清楚。

### 3. 流程集中

发送消息、登录态初始化、思考气泡、缓存保存等流程都在 `ChatController` 中，业务链路更清晰。

### 4. 更容易继续扩展

后面再做这些功能会更方便：

```txt
会话列表
消息分页
重新生成
停止生成
SSE 流式输出
Provider 层
请求拦截器
数据库历史消息
```

### 5. 更接近真实项目

这次重构后，Demo 不只是能跑，而是开始有工程结构了。

## 二十二、测试步骤

### 1. 测试登录态

操作：

```txt
清空应用数据
进入聊天页
```

预期：

```txt
自动跳转 Login 页面
```

登录：

```txt
admin / 123456
```

预期：

```txt
登录成功后进入聊天页
Header 显示当前用户
```

### 2. 测试历史缓存

操作：

```txt
发送一条消息
退出页面
重新进入聊天页
```

预期：

```txt
历史消息仍然存在
```

### 3. 测试 AI 思考气泡

操作：

```txt
输入：你好
点击发送
```

预期：

```txt
先展示用户消息
再展示 AI 思考气泡
思考气泡文案轮播
至少 2 秒后显示真实回复
```

### 4. 测试后端异常

操作：

```txt
关闭 Next.js 后端
发送消息
```

预期：

```txt
AI 思考气泡仍然出现
至少 2 秒后替换成错误提示
错误提示保存到聊天历史
```

### 5. 测试清空聊天

操作：

```txt
点击清空
```

预期：

```txt
页面消息清空
conversationId 重置
本地聊天缓存清空
```

### 6. 测试退出登录

操作：

```txt
点击退出
```

预期：

```txt
清空登录缓存
清空运行时登录状态
跳转 Login 页面
再次进入聊天页需要重新登录
```

### 7. 测试页面释放

操作：

```txt
发送消息过程中切换页面
```

预期：

```txt
aboutToDisappear 调用 release
thinking 定时器被清理
不会继续后台轮播
```

## 二十三、可能遇到的问题

### 1. ChatViewModel 不刷新页面

排查：

```txt
是否使用 @ObservedV2
字段是否使用 @Trace
Setting 中是否用 @Local viewModel
是否通过 ViewModel 方法重新赋值数组
```

数组更新时仍然建议：

```ts
this.chatList = this.chatList.concat([message])
```

不要直接：

```ts
this.chatList.push(message)
```

### 2. AI 气泡不轮播

重点检查 `ForEach` 的 key：

```ts
(item: ChatMessage) => this.chatController.getMessageKey(item)
```

`getMessageKey` 里需要对 thinking 气泡特殊处理：

```ts
if (item.id === this.viewModel.thinkingMessageId) {
  return `${item.id}-${item.content}`
}
```

否则 ArkUI 可能复用旧节点，导致内容不刷新。

### 3. 登录成功后聊天页不能输入

排查：

```txt
viewModel.isAuthReady 是否被设置为 true
ChatController.initAuth 是否调用 viewModel.setAuth
InputBar enabled 是否依赖 isAuthReady
```

### 4. 重构后找不到文件

确认目录：

```txt
entry/src/main/ets/viewmodels/ChatViewModel.ets
entry/src/main/ets/controllers/ChatController.ets
```

确认引用路径：

```ts
import { ChatViewModel } from '../viewmodels/ChatViewModel'
import { ChatController } from '../controllers/ChatController'
```

### 5. 退出页面后定时器没停

确认 `Setting.ets` 中有：

```ts
aboutToDisappear(): void {
  this.chatController.release()
}
```

确认 `ChatController` 中有：

```ts
release(): void {
  this.stopThinkingTimer()
}
```

## 二十四、ArkTS 和工程化注意点

这次重构中继续保持几个写法：

### 1. 请求参数使用明确类型

```ts
const requestParams: ChatRequest = {
  content: content
}
```

不要直接传匿名对象，减少 ArkTS 类型报错。

### 2. 数组更新使用新数组

```ts
this.viewModel.appendMessage(message)
```

内部使用：

```ts
this.chatList = this.chatList.concat([message])
```

不要直接 `push`。

### 3. Controller 不直接操作 UI 组件

Controller 不持有 `Scroller`，只通过回调通知页面滚动。

### 4. 临时 UI 状态不进入缓存

AI 思考气泡是临时状态，不保存到 `ChatStorage`。

### 5. 定时器需要释放

涉及 `setInterval` 的功能，一定要在页面退出或流程结束时清理。

## 二十五、本次知识点总结

本次练习涉及以下知识点：

1. AI 聊天中的等待反馈设计。
2. 使用临时 assistant 消息实现思考气泡。
3. 使用 `setInterval` 实现文案轮播。
4. 使用最小展示时间优化交互体验。
5. 后端返回后替换临时气泡。
6. 临时 UI 状态不进入本地缓存。
7. `ForEach` key 对 UI 刷新的影响。
8. ArkUI 列表节点复用问题。
9. MVVM 基础拆分。
10. View 只负责 UI 和交互入口。
11. ViewModel 负责状态管理。
12. Controller 负责编排业务流程。
13. Storage 负责本地缓存。
14. Api 负责接口请求。
15. 页面滚动属于 UI 行为，不放进 Controller。
16. 定时器需要在页面销毁时释放。
17. 重构不是改功能，而是降低后续维护成本。
18. Demo 结构开始向公司项目靠拢。

## 二十六、面试表达

这个功能可以这样说：

> 我在鸿蒙聊天 Demo 中新增了 AI 思考气泡功能，并对聊天页面做了一次 MVVM + Controller 结构重构。用户发送消息后，页面会先展示用户消息，然后插入一条 assistant 临时气泡，气泡内容会在“AI 正在思考中”“正在整理上下文”“正在生成回复”等文案之间轮播。为了避免后端响应过快导致 loading 一闪而过，我设置了最小 2 秒展示时间。后端返回后，会用真实 assistant 回复替换临时气泡，请求失败时则替换成错误提示。这个临时气泡只作为 UI 状态存在，不会写入本地聊天历史缓存。
>
> 随着登录、本地缓存、AI 思考气泡等功能增加，原来的 `Setting.ets` 页面承担了太多职责，所以我参考公司项目中的 ViewModel 和 Controller 分层，把页面状态拆到 `ChatViewModel.ets`，把登录初始化、发送消息、缓存保存、思考气泡和退出登录等流程拆到 `ChatController.ets`。重构后 `Setting.ets` 主要负责 UI、生命周期、路由跳转和滚动，ViewModel 负责状态，Controller 负责编排业务流程，Api 和 Storage 继续负责请求和缓存。这样 Demo 的结构更接近真实项目，也方便后续继续扩展会话列表、请求封装、Provider 层和数据库历史消息。

## 二十七、本次提交命令

如果 AI 思考气泡和重构一起提交：

```bash
git add entry/src/main/ets/viewmodels/ChatViewModel.ets
git add entry/src/main/ets/controllers/ChatController.ets
git add entry/src/main/ets/pages/Setting.ets
git add docs/06-ai-thinking-bubble-mvvm-refactor.md

git commit -m "refactor: split chat page and add thinking bubble"
git push origin feature/chat-mvvm-refactor
```

如果 AI 思考气泡已经单独提交，本次只提交重构：

```bash
git add entry/src/main/ets/viewmodels/ChatViewModel.ets
git add entry/src/main/ets/controllers/ChatController.ets
git add entry/src/main/ets/pages/Setting.ets
git add docs/06-ai-thinking-bubble-mvvm-refactor.md

git commit -m "refactor: split chat page into viewmodel and controller"
git push origin feature/chat-mvvm-refactor
```

合并到 `ai-chat`：

```bash
git checkout ai-chat
git pull origin ai-chat
git merge feature/chat-mvvm-refactor
git push origin ai-chat
```

删除本地分支：

```bash
git branch -d feature/chat-mvvm-refactor
```

删除远程分支：

```bash
git push origin --delete feature/chat-mvvm-refactor
```

## 二十八、本次练习总结

这一节的重点不是继续堆新功能，而是让 Demo 从“功能能跑”开始走向“结构清晰”。

本次完成了两个关键动作：

```txt
AI 思考气泡：优化聊天等待体验
MVVM + Controller 重构：优化代码组织方式
```

通过这次练习，我理解了：

1. AI 聊天产品中，等待反馈很重要。
2. loading 不一定只能放在按钮上，也可以作为一条临时消息展示。
3. 临时消息和真实历史消息要区分。
4. 最小展示时间可以避免 loading 一闪而过。
5. ArkUI 列表刷新和 key 有关系。
6. 页面不应该无限堆业务逻辑。
7. ViewModel 适合管理页面状态。
8. Controller 适合编排一次完整业务流程。
9. Storage 和 Api 应该继续保持独立职责。
10. 重构后的结构更方便继续对照公司项目学习。

目前 Demo 已经具备：

```txt
基础聊天页面
自动滚动
打字机 / loading 基础能力
Next.js 后端接口
聊天历史本地缓存
登录功能
AI 思考气泡
MVVM + Controller 分层
```

后续可以继续扩展：

```txt
通用 Request 请求封装
ChatProvider 抽象层
登录路由拦截器
Authorization 请求头
会话列表
消息分页
停止生成
SSE 流式回复
数据库历史消息
```

这时再继续加功能，代码结构会比之前稳很多。
