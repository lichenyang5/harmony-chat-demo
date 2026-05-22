# 鸿蒙聊天 Demo 练习 04：聊天历史本地缓存，实现消息记录持久化

## 一、本次分支

```bash
feature/chat-local-storage
```

## 二、本次目标

本次在原有聊天 Demo 的基础上，给聊天页面新增本地历史记录缓存能力。

之前聊天消息只保存在页面状态 `chatList` 里，只要退出页面、刷新页面或者重启应用，聊天记录就会丢失。

本次要把聊天记录保存到鸿蒙本地 `Preferences` 中，让聊天记录可以持久化保存。

本次完成的核心流程：

1. 新增 `ChatStorage.ets`，专门封装聊天记录本地缓存。
2. 使用 `Preferences` 保存 `conversationId` 和 `chatList`。
3. 页面进入时读取本地缓存并恢复聊天记录。
4. 用户发送消息后，立即保存用户消息。
5. 后端返回 assistant 回复后，再次保存完整聊天记录。
6. 请求失败时，也把错误提示消息保存下来。
7. Header 区域新增“清空”按钮。
8. 点击清空后，同时清空页面状态和本地缓存。

最终效果：

```txt
用户发送消息
↓
页面展示用户消息
↓
保存到本地缓存
↓
调用后端接口
↓
页面展示 assistant 回复
↓
再次保存到本地缓存
↓
退出页面 / 重启应用
↓
再次进入聊天页
↓
自动恢复历史聊天记录
```

本次还没有做多会话列表，也没有接入数据库，只是先完成单个会话的本地持久化，为后续登录、token 保存、会话列表和数据库历史消息打基础。

## 三、涉及文件

```txt
entry/src/main/ets/models/ChatModel.ets
entry/src/main/ets/utils/ChatStorage.ets
entry/src/main/ets/pages/Setting.ets
docs/04-chat-local-storage.md
```

## 四、为什么要做聊天历史缓存

之前聊天 Demo 的数据流是：

```txt
用户输入
↓
创建用户消息
↓
追加到 chatList
↓
请求后端
↓
创建 assistant 消息
↓
追加到 chatList
```

这个流程可以完成聊天展示，但是有一个明显问题：

```txt
chatList 只是页面内存状态，不是持久化数据。
```

也就是说：

```txt
页面还在，消息就在
页面销毁，消息就没了
应用重启，消息也没了
```

真实项目中，聊天记录、用户信息、token、草稿、设置项等数据，很多都需要本地保存。

所以本次把聊天流程改造成：

```txt
鸿蒙页面
↓
chatList 状态更新
↓
ChatStorage 保存到 Preferences
↓
页面重新进入时读取 Preferences
↓
恢复聊天记录
```

这样 Demo 就从“临时页面状态”升级成了“有本地持久化能力”的应用。

## 五、项目结构变化

本次主要新增了一个 `utils` 工具目录，用来放本地缓存逻辑。

```txt
entry/src/main/ets
├── api
│   └── ChatApi.ets
│
├── constants
│   ├── ApiConstants.ets
│   └── RouteConstants.ets
│
├── models
│   └── ChatModel.ets
│
├── pages
│   └── Setting.ets
│
├── stores
│   └── TabState.ets
│
└── utils
    └── ChatStorage.ets
```

现在聊天相关代码大概可以分成三层：

```txt
pages/Setting.ets
  页面层，负责 UI 展示、输入、点击、调用方法

api/ChatApi.ets
  接口层，负责请求 Next.js 后端

utils/ChatStorage.ets
  本地存储层，负责保存和读取聊天历史

models/ChatModel.ets
  类型层，负责统一消息结构
```

这次的重点不是单纯会用 `Preferences`，而是把缓存逻辑从页面里拆出来，让页面不要越来越臃肿。

## 六、聊天消息模型

文件：

```txt
entry/src/main/ets/models/ChatModel.ets
```

代码：

```ts
export interface ChatMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}
```

这个类型表示页面里真正要展示的一条聊天消息。

字段说明：

```txt
id：消息唯一标识
role：消息角色，用户消息是 user，AI 回复是 assistant
content：消息内容
createTime：消息创建时间
```

这里统一使用：

```ts
role: 'user' | 'assistant'
```

而不是：

```ts
type: 'user' | 'ai'
```

原因是 `role` 更接近真实聊天接口设计，后续接入真实 AI 接口、数据库消息表、OpenAI 风格接口时更容易对齐。

## 七、新增 ChatStorage 本地缓存工具

文件：

```txt
entry/src/main/ets/utils/ChatStorage.ets
```

完整代码：

```ts
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { ChatMessage } from '../models/ChatModel'

interface ChatCacheData {
  conversationId: number
  chatList: ChatMessage[]
}

export class ChatStorage {
  private static readonly STORE_NAME: string = 'chat_storage'
  private static readonly CHAT_CACHE_KEY: string = 'chat_cache'

  static async saveChatCache(
    context: common.UIAbilityContext,
    conversationId: number,
    chatList: ChatMessage[]
  ): Promise<void> {
    const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)

    const cacheData: ChatCacheData = {
      conversationId,
      chatList
    }

    await pref.put(ChatStorage.CHAT_CACHE_KEY, JSON.stringify(cacheData))
    await pref.flush()
  }

  static async getChatCache(context: common.UIAbilityContext): Promise<ChatCacheData> {
    const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)
    const cacheValue = await pref.get(ChatStorage.CHAT_CACHE_KEY, '')

    if (typeof cacheValue !== 'string' || cacheValue.length === 0) {
      return {
        conversationId: 0,
        chatList: []
      }
    }

    try {
      const cacheData = JSON.parse(cacheValue) as ChatCacheData

      return {
        conversationId: cacheData.conversationId || 0,
        chatList: cacheData.chatList || []
      }
    } catch (error) {
      console.error(`parse chat cache error: ${JSON.stringify(error)}`)

      return {
        conversationId: 0,
        chatList: []
      }
    }
  }

  static async clearChatCache(context: common.UIAbilityContext): Promise<void> {
    const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)
    await pref.delete(ChatStorage.CHAT_CACHE_KEY)
    await pref.flush()
  }
}
```

## 八、ChatStorage 的职责

`ChatStorage` 只做三件事：

```txt
saveChatCache：保存聊天缓存
getChatCache：读取聊天缓存
clearChatCache：清空聊天缓存
```

页面不需要关心：

```txt
Preferences 怎么创建
缓存 key 是什么
数据怎么 JSON.stringify
数据怎么 JSON.parse
异常时怎么兜底
```

页面只需要调用：

```ts
await ChatStorage.saveChatCache(context, this.conversationId, this.chatList)
```

这样就完成了页面层和存储层的解耦。

## 九、为什么要同时保存 conversationId 和 chatList

这次不是只保存消息列表，而是保存了：

```txt
conversationId
chatList
```

原因是当前聊天接口已经支持 `conversationId`。

如果只保存 `chatList`，不保存 `conversationId`，就会出现一个问题：

```txt
页面看起来恢复了旧聊天记录
但是下一次发消息时，后端不知道属于哪个会话
```

所以本地缓存结构设计成：

```ts
interface ChatCacheData {
  conversationId: number
  chatList: ChatMessage[]
}
```

这样页面恢复时可以同时恢复：

```txt
当前会话 ID
当前会话消息列表
```

## 十、Preferences 的基本使用流程

本次使用的是鸿蒙的 `Preferences`。

核心流程是：

```txt
获取 Preferences 实例
↓
put 写入数据
↓
flush 持久化
```

保存缓存：

```ts
const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)

await pref.put(ChatStorage.CHAT_CACHE_KEY, JSON.stringify(cacheData))
await pref.flush()
```

读取缓存：

```ts
const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)
const cacheValue = await pref.get(ChatStorage.CHAT_CACHE_KEY, '')
```

删除缓存：

```ts
const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)
await pref.delete(ChatStorage.CHAT_CACHE_KEY)
await pref.flush()
```

这里要注意：

```txt
put 之后要 flush
delete 之后也要 flush
```

否则数据可能只是更新到了内存里，没有真正持久化到本地。

## 十一、为什么要 JSON.stringify

`Preferences` 适合保存简单数据。

但是这次要保存的是一个对象：

```ts
{
  conversationId: 123,
  chatList: []
}
```

所以需要先转成字符串：

```ts
JSON.stringify(cacheData)
```

读取出来之后再转回对象：

```ts
JSON.parse(cacheValue)
```

整体流程：

```txt
对象
↓
JSON.stringify
↓
字符串
↓
Preferences
↓
字符串
↓
JSON.parse
↓
对象
```

## 十二、修改 Setting 页面

文件：

```txt
entry/src/main/ets/pages/Setting.ets
```

本次在 `Setting.ets` 中主要做了这些改动：

1. 引入 `common`。
2. 引入 `ChatMessage`。
3. 引入 `ChatStorage`。
4. 页面进入时读取缓存。
5. 发送消息后保存缓存。
6. assistant 回复后保存缓存。
7. 请求失败时保存错误提示。
8. 新增清空聊天历史方法。
9. Header 增加“清空”按钮。

## 十三、Setting.ets 新增引用

```ts
import { common } from '@kit.AbilityKit'

import { ChatMessage } from '../models/ChatModel'
import { ChatStorage } from '../utils/ChatStorage'
```

`common.UIAbilityContext` 用来给 `Preferences` 提供上下文。

`ChatMessage` 用来统一聊天消息类型。

`ChatStorage` 用来读写本地聊天缓存。

## 十四、chatList 类型调整

原来如果页面里自己定义了 `ChatItem`：

```ts
interface ChatItem {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}
```

现在可以删掉，统一使用模型文件里的 `ChatMessage`：

```ts
@Local chatList: ChatMessage[] = []
```

这样做的好处是：

```txt
页面展示使用 ChatMessage
本地缓存使用 ChatMessage
后续数据库消息也可以参考 ChatMessage
```

类型统一之后，后面维护会更简单。

## 十五、页面进入时读取本地缓存

在 `aboutToAppear` 中调用：

```ts
aboutToAppear(): void {
  globalTabState.setCurrentTab(RouteConstants.SETTING)

  this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)

  this.loadChatCache()
}
```

新增读取方法：

```ts
async loadChatCache(): Promise<void> {
  const context = getContext(this) as common.UIAbilityContext
  const cacheData = await ChatStorage.getChatCache(context)

  this.conversationId = cacheData.conversationId
  this.chatList = cacheData.chatList

  this.scrollToBottom()
}
```

这里没有把 `aboutToAppear` 直接写成 `async`，而是单独封装了 `loadChatCache`。

这样写更清晰：

```txt
aboutToAppear：负责生命周期入口
loadChatCache：负责异步读取缓存
```

## 十六、保存聊天缓存方法

新增方法：

```ts
async saveChatCache(): Promise<void> {
  const context = getContext(this) as common.UIAbilityContext
  await ChatStorage.saveChatCache(context, this.conversationId, this.chatList)
}
```

这样页面里每次需要保存时，只需要写：

```ts
await this.saveChatCache()
```

不用每次都重复写：

```ts
getContext
ChatStorage.saveChatCache
conversationId
chatList
```

## 十七、发送用户消息后保存

原来发送消息时，只是把用户消息追加到 `chatList`：

```ts
this.chatList = this.chatList.concat([tempUserMessage])
this.scrollToBottom()
```

现在改成：

```ts
this.chatList = this.chatList.concat([tempUserMessage])
await this.saveChatCache()
this.scrollToBottom()
```

这样做的好处是：

```txt
用户消息先展示
用户消息立即保存
即使后端请求失败，用户刚才发的内容也不会丢
```

## 十八、assistant 回复后保存

拿到后端返回的 assistant 消息后：

```ts
this.chatList = this.chatList.concat(assistantMessages)
await this.saveChatCache()
this.scrollToBottom()
```

这一步保存的是完整聊天记录：

```txt
用户消息
assistant 回复
conversationId
```

这样下次进入页面时，聊天上下文可以完整恢复。

## 十九、请求失败时也保存错误消息

如果后端返回异常：

```ts
const failMessage: ChatMessage = {
  id: Date.now(),
  role: 'assistant',
  content: res.message || '后端返回异常，请稍后重试。',
  createTime: Date.now()
}

this.chatList = this.chatList.concat([failMessage])
await this.saveChatCache()
this.scrollToBottom()
```

如果请求直接失败：

```ts
const errorMessage: ChatMessage = {
  id: Date.now(),
  role: 'assistant',
  content: '请求后端失败，请检查 Next.js 服务是否启动，以及接口地址是否正确。',
  createTime: Date.now()
}

this.chatList = this.chatList.concat([errorMessage])
await this.saveChatCache()
this.scrollToBottom()
```

这样做的原因是：

```txt
错误提示也是聊天页面的一部分
用户下次进入页面时，能看到上次失败的上下文
方便排查问题
```

## 二十、新增清空聊天历史功能

新增方法：

```ts
async clearChatHistory(): Promise<void> {
  const context = getContext(this) as common.UIAbilityContext

  this.chatList = []
  this.conversationId = 0

  await ChatStorage.clearChatCache(context)
}
```

这里需要同时清空三个东西：

```txt
chatList：页面上的消息
conversationId：当前会话 ID
Preferences：本地缓存
```

不能只清空 `chatList`。

如果只清空页面消息，不清空 `conversationId`，下一次发送消息时还可能继续沿用旧会话 ID。

## 二十一、Header 新增清空按钮

原来的 Header 只有标题。

本次改成：

```ts
@Builder
Header() {
  Row() {
    Text('聊天 Demo')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#222222')

    Blank()

    Button('清空')
      .height(32)
      .fontSize(14)
      .enabled(this.chatList.length > 0 && !this.isSending)
      .onClick(() => {
        this.clearChatHistory()
      })
  }
  .width('100%')
  .height(56)
  .padding({ left: 16, right: 16 })
  .backgroundColor(Color.White)
  .alignItems(VerticalAlign.Center)
}
```

这里用了：

```ts
Blank()
```

让标题靠左，按钮靠右。

按钮禁用条件是：

```ts
.enabled(this.chatList.length > 0 && !this.isSending)
```

意思是：

```txt
没有聊天记录时不能点
正在发送消息时不能点
```

这样可以避免一些异常操作。

## 二十二、完整聊天流程

### 1. 页面初始化流程

```txt
进入 Setting 页面
↓
aboutToAppear 执行
↓
调用 loadChatCache
↓
读取 Preferences
↓
恢复 conversationId
↓
恢复 chatList
↓
滚动到底部
```

### 2. 发送消息流程

```txt
用户输入内容
↓
点击发送
↓
校验内容是否为空
↓
设置 isSending = true
↓
清空输入框
↓
创建用户消息
↓
追加到 chatList
↓
保存本地缓存
↓
调用 sendChatMessage
↓
拿到后端返回
↓
更新 conversationId
↓
过滤 assistant 消息
↓
追加到 chatList
↓
再次保存本地缓存
↓
滚动到底部
↓
设置 isSending = false
```

### 3. 清空历史流程

```txt
点击清空按钮
↓
chatList = []
↓
conversationId = 0
↓
删除 Preferences 缓存
```

## 二十三、为什么还是用 concat

这次继续使用：

```ts
this.chatList = this.chatList.concat([newMessage])
```

而不是：

```ts
this.chatList.push(newMessage)
```

原因是：

```txt
concat 会返回一个新数组
push 是在原数组上修改
```

在 ArkUI 状态更新里，使用新数组赋值更容易触发 UI 刷新。

也就是说：

```ts
this.chatList = this.chatList.concat([tempUserMessage])
```

这行代码的意思是：

```txt
基于旧数组生成一个新数组
再把新数组重新赋值给 chatList
```

这比直接 `push` 更适合响应式页面状态更新。

## 二十四、ArkTS 类型注意点

这次依然要注意 ArkTS 的类型严格性。

不建议直接写复杂匿名对象到函数参数里：

```ts
await ChatStorage.saveChatCache(context, this.conversationId, this.chatList)
```

这个没问题，因为参数类型明确。

但是如果是请求参数，最好不要写成：

```ts
const res = await sendChatMessage({
  conversationId: this.conversationId || undefined,
  content
})
```

更推荐：

```ts
const requestParams: ChatRequest = {
  content: content
}

if (this.conversationId > 0) {
  requestParams.conversationId = this.conversationId
}

const res = await sendChatMessage(requestParams)
```

这也是之前遇到 `Object literal must correspond to some explicitly declared class or interface` 后总结出来的经验。

## 二十五、可能遇到的问题

### 1. Cannot find module '../utils/ChatStorage'

原因：

```txt
ChatStorage.ets 文件没有创建
路径写错
utils 目录位置不对
```

检查文件是否在：

```txt
entry/src/main/ets/utils/ChatStorage.ets
```

引用路径应该是：

```ts
import { ChatStorage } from '../utils/ChatStorage'
```

### 2. Cannot find module '../models/ChatModel'

原因：

```txt
ChatModel.ets 文件不存在
或者里面没有导出 ChatMessage
```

确认文件内容：

```ts
export interface ChatMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}
```

### 3. Preferences 读取后没有恢复消息

排查顺序：

```txt
1. 发送消息后是否调用了 saveChatCache
2. saveChatCache 里是否调用了 pref.flush()
3. getChatCache 是否正确读取 CHAT_CACHE_KEY
4. JSON.parse 是否报错
5. chatList 是否重新赋值
```

可以加日志：

```ts
console.info(`chat cache data: ${JSON.stringify(cacheData)}`)
```

### 4. 清空后重新进入页面又恢复旧数据

可能原因：

```txt
只清空了 chatList，没有删除 Preferences
delete 后没有 flush
清空的是错误的 key
```

确认清空方法里有：

```ts
await pref.delete(ChatStorage.CHAT_CACHE_KEY)
await pref.flush()
```

### 5. 点击清空后下一次聊天还沿用旧会话

原因：

```txt
清空时没有把 conversationId 重置为 0
```

正确做法：

```ts
this.chatList = []
this.conversationId = 0
await ChatStorage.clearChatCache(context)
```

## 二十六、测试步骤

### 1. 启动后端

如果当前聊天接口依赖 Next.js 后端，先启动后端：

```bash
cd server
npm run dev
```

如果第一次启动，需要先安装依赖：

```bash
cd server
npm install
npm run dev
```

### 2. 启动鸿蒙应用

用 DevEco Studio 运行到模拟器或真机。

### 3. 测试发送消息

输入：

```txt
你好
```

预期页面展示：

```txt
用户消息：你好
assistant 回复：这是 Next.js 后端返回的模拟回复：你好
```

### 4. 测试返回页面后恢复

操作：

```txt
切到其他页面
再回到聊天页面
```

预期：

```txt
刚才的聊天记录还在
```

### 5. 测试重启应用后恢复

操作：

```txt
关闭应用
重新打开应用
进入聊天页
```

预期：

```txt
历史聊天记录仍然存在
```

### 6. 测试清空聊天记录

点击右上角：

```txt
清空
```

预期：

```txt
页面消息清空
清空按钮禁用
重新进入页面后仍然为空
```

### 7. 测试清空后重新发送

再次输入：

```txt
重新开始
```

预期：

```txt
可以正常发送
conversationId 从新的会话开始
历史旧消息不会恢复
```

## 二十七、本次知识点总结

本次练习涉及以下知识点：

1. 鸿蒙 `Preferences` 本地存储。
2. `preferences.getPreferences` 获取本地存储实例。
3. `pref.put` 写入缓存。
4. `pref.get` 读取缓存。
5. `pref.delete` 删除缓存。
6. `pref.flush` 持久化缓存变更。
7. 使用 `JSON.stringify` 保存复杂对象。
8. 使用 `JSON.parse` 恢复复杂对象。
9. 页面进入时通过 `aboutToAppear` 初始化数据。
10. 异步生命周期逻辑可以拆成单独方法。
11. `chatList` 使用 `concat` 触发 UI 更新。
12. 页面层和存储层解耦。
13. `conversationId` 和消息列表要一起保存。
14. 清空历史时要同时清空页面状态和本地缓存。
15. 为后续 token、本地用户信息、会话列表缓存打基础。

## 二十八、面试表达

这个功能可以这样说：

> 我在鸿蒙聊天 Demo 中新增了聊天历史本地持久化能力。之前聊天记录只保存在页面的 `chatList` 状态里，页面销毁或应用重启后数据就会丢失。为了解决这个问题，我新增了 `ChatStorage.ets`，使用鸿蒙 `Preferences` 保存 `conversationId` 和 `chatList`，并在页面 `aboutToAppear` 时读取缓存，恢复历史聊天记录。发送用户消息、收到 assistant 回复以及请求失败生成错误消息后，都会同步更新本地缓存。另外我还在 Header 中新增了清空按钮，点击后会同时清空页面消息、重置 `conversationId`，并删除本地缓存。这个功能让我练习了鸿蒙本地存储、页面生命周期、异步初始化、JSON 序列化和页面层与存储层的职责拆分。

## 二十九、本次提交命令

```bash
git add entry/src/main/ets/models/ChatModel.ets
git add entry/src/main/ets/utils/ChatStorage.ets
git add entry/src/main/ets/pages/Setting.ets
git add docs/04-chat-local-storage.md

git commit -m "feat: add chat local storage"
git push origin feature/chat-local-storage
```

如果合并到 main：

```bash
git checkout main
git pull
git merge feature/chat-local-storage
git push
```

删除本地分支：

```bash
git branch -d feature/chat-local-storage
```

删除远程分支：

```bash
git push origin --delete feature/chat-local-storage
```

## 三十、本次练习总结

这一节的重点不是做一个复杂的聊天系统，而是补齐聊天 Demo 中非常关键的一环：

```txt
页面状态
↓
本地缓存
↓
重新进入页面
↓
状态恢复
```

通过这次练习，我理解了几个关键点：

1. `@Local` 状态只适合页面运行时展示，不适合长期保存。
2. 需要持久化的数据应该放到本地存储或数据库中。
3. `Preferences` 适合保存轻量级本地数据。
4. 复杂对象要通过 `JSON.stringify` 转成字符串保存。
5. 读取缓存时要做好空值和 JSON 解析异常兜底。
6. 页面不要直接堆太多存储逻辑，应该抽成 `ChatStorage`。
7. 清空聊天记录时，不仅要清空页面，还要清空缓存和会话 ID。
8. 本地缓存能力可以继续复用到登录 token、用户信息、主题设置等功能。

目前 Demo 已经具备了基础聊天、后端接口请求和本地历史缓存能力。

后续如果继续扩展，可以进入下一节：

```txt
请求封装升级：抽离通用 Request 工具
```

再往后就可以继续做：

```txt
登录页
登录状态保存
路由登录拦截
会话列表
后端数据库
```

这样整个 Demo 会越来越接近真实业务项目。
