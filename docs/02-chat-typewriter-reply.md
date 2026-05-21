# 鸿蒙聊天 Demo 练习 02：AI 回复打字机输出与 ForEach 刷新问题

## 一、本次分支

```bash
feature/chat-typewriter-reply
```

## 二、本次目标

本次在聊天 Demo 的基础上，新增 AI 回复的打字机输出效果。

上一节中，AI 回复是一次性显示的：

```text
用户发送消息
  ↓
AI 回复整段文本
```

本次改成：

```text
用户发送消息
  ↓
追加用户消息
  ↓
追加一条 AI 消息
  ↓
AI 消息先显示“AI 正在思考...”
  ↓
定时器逐字更新这条 AI 消息的 content
  ↓
页面逐字刷新
  ↓
打字结束后恢复发送状态
```

本次不仅练习了打字机效果，还遇到了一个很重要的问题：

```text
ForEach 的 key 如果只使用 id，更新同一条消息的 content 时，页面可能不会稳定刷新。
```

最终解决方案是：

```ts
}, (item: ChatItem) => `${item.id}-${item.content}`)
```

也就是让 `key` 同时包含 `id` 和 `content`。

---

## 三、涉及文件

```text
entry/src/main/ets/pages/Setting.ets
docs/02-chat-typewriter-reply.md
```

---

## 四、本次功能效果

输入：

```text
你好
```

页面显示流程：

```text
用户：你好

AI：AI 正在思考...

AI：你

AI：你刚

AI：你刚才

AI：你刚才说

AI：你刚才说的是：你好。...
```

最终完整显示：

```text
你刚才说的是：你好。这是一个模拟 AI 回复，当前正在使用打字机效果逐字输出。
```

---

## 五、核心数据结构

聊天消息仍然使用 `ChatItem`：

```ts
interface ChatItem {
  id: number
  type: 'user' | 'ai'
  content: string
}
```

字段说明：

| 字段 | 作用 |
| --- | --- |
| id | 消息唯一标识 |
| type | 区分用户消息和 AI 消息 |
| content | 消息内容 |

用户消息：

```ts
{
  id: 1,
  type: 'user',
  content: '你好'
}
```

AI 消息：

```ts
{
  id: 2,
  type: 'ai',
  content: 'AI 正在思考...'
}
```

---

## 六、新增 typingTimer

为了实现打字机效果，需要新增一个定时器变量：

```ts
private typingTimer: number = -1
```

这个变量用来保存 `setInterval` 返回的定时器 id。

为什么初始值是 `-1`？

因为可以这样理解：

```text
-1：当前没有正在运行的打字机定时器
非 -1：当前有正在运行的打字机定时器
```

后面清理定时器时，就可以判断：

```ts
if (this.typingTimer !== -1) {
  clearInterval(this.typingTimer)
  this.typingTimer = -1
}
```

---

## 七、为什么要在 aboutToDisappear 里清理定时器

页面离开时，如果定时器还在执行，就可能出现两个问题：

```text
1. 页面已经销毁了，但定时器还在跑
2. 定时器继续修改页面状态，可能造成异常或性能浪费
```

所以要在生命周期里清理：

```ts
aboutToDisappear(): void {
  if (this.typingTimer !== -1) {
    clearInterval(this.typingTimer)
    this.typingTimer = -1
  }
}
```

这里用到的是鸿蒙组件生命周期：

```text
aboutToAppear：组件即将出现
aboutToDisappear：组件即将消失
```

本次 `aboutToDisappear` 的作用就是：

```text
页面离开时，停止还没完成的打字机任务。
```

---

## 八、发送消息流程

发送消息的方法还是 `sendMsg`：

```ts
sendMsg(): void {
  const text: string = this.inputValue.trim()

  if (text === '') {
    return
  }

  if (this.isSending) {
    return
  }

  const userItem: ChatItem = {
    id: this.nextId++,
    type: 'user',
    content: text
  }

  this.chatList = this.chatList.concat([userItem])
  this.inputValue = ''
  this.isSending = true

  this.scrollToBottom()
  this.mockAskAi(text)
}
```

这段逻辑可以拆成几步：

```text
1. 获取输入框内容
2. trim 去掉前后空格
3. 如果是空字符串，直接 return
4. 如果正在发送中，直接 return，防止重复点击
5. 创建用户消息
6. 用 concat 追加到 chatList
7. 清空输入框
8. 设置 isSending = true
9. 滚动到底部
10. 调用 mockAskAi 模拟 AI 回复
```

---

## 九、为什么继续用 concat 新增消息

新增用户消息时：

```ts
this.chatList = this.chatList.concat([userItem])
```

新增 AI 消息时：

```ts
this.chatList = this.chatList.concat([aiItem])
```

`concat` 的特点是：

```text
1. 保留旧数组中的所有元素
2. 把新元素追加到后面
3. 返回一个新的数组
4. 原数组不变
```

比如：

```ts
const oldList = ['你好']
const newList = oldList.concat(['你好呀'])
```

结果是：

```ts
oldList // ['你好']
newList // ['你好', '你好呀']
```

在响应式页面里，重新赋值一个新数组更容易触发 UI 更新：

```ts
this.chatList = 新数组
```

所以聊天消息新增时，推荐使用：

```ts
this.chatList = this.chatList.concat([newItem])
```

---

## 十、打字机回复核心方法

本次核心方法是 `mockAskAi`：

```ts
mockAskAi(question: string): void {
  const fullText: string = `你刚才说的是：${question}。这是一个模拟 AI 回复，当前正在使用打字机效果逐字输出。`

  const aiItem: ChatItem = {
    id: this.nextId++,
    type: 'ai',
    content: 'AI 正在思考...'
  }

  this.chatList = this.chatList.concat([aiItem])
  this.scrollToBottom()

  let currentIndex: number = 0

  setTimeout(() => {
    this.typingTimer = setInterval(() => {
      currentIndex++

      const currentText: string = fullText.slice(0, currentIndex)

      this.chatList = this.chatList.map((item: ChatItem) => {
        if (item.id === aiItem.id) {
          return {
            id: item.id,
            type: item.type,
            content: currentText
          }
        }

        return item
      })

      this.scrollToBottom()

      if (currentIndex >= fullText.length) {
        clearInterval(this.typingTimer)
        this.typingTimer = -1
        this.isSending = false
      }
    }, 60)
  }, 500)
}
```

这段代码可以拆成六步理解。

---

## 十一、第一步：准备完整回复文本

```ts
const fullText: string = `你刚才说的是：${question}。这是一个模拟 AI 回复，当前正在使用打字机效果逐字输出。`
```

`fullText` 是 AI 最终要完整显示的内容。

比如用户输入：

```text
你好
```

那么完整回复就是：

```text
你刚才说的是：你好。这是一个模拟 AI 回复，当前正在使用打字机效果逐字输出。
```

但是它不会一次性展示，而是后面通过 `slice` 一点点截取。

---

## 十二、第二步：先创建一条 AI 消息

```ts
const aiItem: ChatItem = {
  id: this.nextId++,
  type: 'ai',
  content: 'AI 正在思考...'
}
```

这里没有让 `content` 为空字符串，而是先显示：

```text
AI 正在思考...
```

这样用户点击发送后，页面能立刻看到反馈。

一开始我们写过：

```ts
content: ''
```

这会导致页面上刚追加 AI 消息时看起来没有反应。

所以更好的方式是：

```ts
content: 'AI 正在思考...'
```

这样用户体验更清楚。

---

## 十三、第三步：延迟 500ms 后开始打字

```ts
setTimeout(() => {
  this.typingTimer = setInterval(() => {
    ...
  }, 60)
}, 500)
```

这里用了两层定时：

```text
setTimeout：模拟 AI 思考 500ms
setInterval：开始逐字输出，每 60ms 输出一个字
```

流程是：

```text
先显示“AI 正在思考...”
等待 500ms
开始一个字一个字输出正式回复
```

---

## 十四、第四步：使用 currentIndex 控制输出进度

```ts
let currentIndex: number = 0

this.typingTimer = setInterval(() => {
  currentIndex++
}, 60)
```

`currentIndex` 表示当前输出到第几个字。

比如完整文本是：

```text
你好呀
```

那么输出过程是：

```text
currentIndex = 1 => 你
currentIndex = 2 => 你好
currentIndex = 3 => 你好呀
```

---

## 十五、第五步：使用 slice 截取当前内容

```ts
const currentText: string = fullText.slice(0, currentIndex)
```

`slice(0, currentIndex)` 表示从完整文本中截取一部分。

例如：

```ts
const fullText = '你好呀'
```

执行结果：

```text
fullText.slice(0, 1) => 你
fullText.slice(0, 2) => 你好
fullText.slice(0, 3) => 你好呀
```

所以打字机效果的本质是：

```text
完整文本 fullText
  ↓
currentIndex 不断增加
  ↓
slice 截取越来越长的文本
  ↓
页面看到的文字越来越多
```

---

## 十六、第六步：使用 map 更新指定 AI 消息

打字机不是不断新增 AI 消息，而是更新同一条 AI 消息。

所以用了：

```ts
this.chatList = this.chatList.map((item: ChatItem) => {
  if (item.id === aiItem.id) {
    return {
      id: item.id,
      type: item.type,
      content: currentText
    }
  }

  return item
})
```

这段代码的意思是：

```text
遍历 chatList
找到 id 等于 aiItem.id 的那条消息
把它的 content 更新成 currentText
其他消息保持不变
最后返回一个新数组
重新赋值给 chatList
```

举例：

```ts
[
  { id: 1, type: 'user', content: '你好' },
  { id: 2, type: 'ai', content: 'AI 正在思考...' }
]
```

第一次更新：

```ts
[
  { id: 1, type: 'user', content: '你好' },
  { id: 2, type: 'ai', content: '你' }
]
```

第二次更新：

```ts
[
  { id: 1, type: 'user', content: '你好' },
  { id: 2, type: 'ai', content: '你刚' }
]
```

第三次更新：

```ts
[
  { id: 1, type: 'user', content: '你好' },
  { id: 2, type: 'ai', content: '你刚才' }
]
```

---

## 十七、为什么 map 适合更新数组中的某一项

`map` 的特点是：

```text
1. 遍历数组
2. 对每一项执行回调
3. 根据回调返回值生成新数组
4. 不直接修改原数组
```

在聊天 Demo 中可以这样记：

```text
新增消息：用 concat
修改消息：用 map
```

本次打字机输出需要不断修改同一条 AI 消息，所以用 `map`。

---

## 十八、这次遇到的关键 bug：内容变了但页面不刷新

这次调试中遇到的问题是：

```text
输入“你好”后，逻辑在执行，定时器也在循环输出，但页面没有明显刷新。
```

一开始的 `ForEach` 写法是：

```ts
ForEach(this.chatList, (item: ChatItem) => {
  ...
}, (item: ChatItem) => item.id.toString())
```

这里的 key 只和 `id` 有关。

但是打字机过程中，AI 消息的变化是：

```text
id 不变
type 不变
content 一直变
```

比如：

```ts
{ id: 2, type: 'ai', content: '你' }
{ id: 2, type: 'ai', content: '你刚' }
{ id: 2, type: 'ai', content: '你刚才' }
```

因为 `id` 一直是 `2`，所以 key 一直没变：

```text
2
2
2
2
```

列表项可能会被复用，页面没有稳定根据 `content` 的变化刷新。

---

## 十九、解决方案：让 key 包含 content

最终把 key 改成：

```ts
}, (item: ChatItem) => `${item.id}-${item.content}`)
```

这样当 `content` 变化时，key 也会变化。

例如：

```text
2-你
2-你刚
2-你刚才
2-你刚才说
```

这样 `ForEach` 更容易识别到列表项发生了变化，页面能看到逐字刷新效果。

---

## 二十、这是不是最佳写法

对于当前学习阶段来说，这个写法很好理解，也很好验证：

```ts
}, (item: ChatItem) => `${item.id}-${item.content}`)
```

优点是：

```text
1. 简单直观
2. content 变化时页面能刷新
3. 适合学习打字机效果
```

但它也有一个需要注意的地方：

```text
content 每变化一次，key 都变化一次，组件可能会重新创建。
```

对于当前 Demo 来说完全可以接受。

后面如果项目复杂了，可以考虑更细的状态设计，比如：

```text
1. 把消息气泡拆成独立组件
2. 给消息对象增加 version 字段
3. 更新 content 时同步更新 version
4. key 使用 id + version
```

但是现阶段先掌握这个问题最重要：

```text
ForEach 的 key 会影响列表刷新。
```

---

## 二十一、为什么删除单独的“AI 正在思考...” ListItem

之前有一段逻辑：

```ts
if (this.isSending) {
  ListItem() {
    Row() {
      Text('AI 正在思考...')
      Blank()
    }
  }
}
```

这会导致页面中同时存在两种东西：

```text
1. chatList 里的一条 AI 消息
2. isSending 额外渲染出来的一条 loading 消息
```

这样会让逻辑变复杂。

本次改成：

```text
AI 正在思考...
```

也是一条真正的 AI 消息，放在 `chatList` 里面。

然后后续打字机效果继续更新这条消息。

这样数据流更统一：

```text
所有聊天内容都来自 chatList
```

---

## 二十二、滚动到底部逻辑

滚动方法仍然是：

```ts
scrollToBottom(): void {
  setTimeout(() => {
    this.listScroller.scrollToIndex(this.chatList.length)
  }, 50)
}
```

为什么用 `setTimeout`？

因为更新 `chatList` 后，列表不一定立刻完成渲染。

所以延迟一点再滚动，比较稳定：

```text
先更新数据
等待 UI 渲染
再滚动到底部
```

为什么滚动到 `this.chatList.length`？

因为列表最后还有一个底部占位项：

```ts
ListItem() {
  Row() {
    Blank()
  }
  .height(12)
}
```

假设有 3 条消息：

```text
索引 0：第一条消息
索引 1：第二条消息
索引 2：第三条消息
索引 3：底部占位项
```

所以：

```ts
this.listScroller.scrollToIndex(this.chatList.length)
```

刚好滚动到底部占位项。

---

## 二十三、打字结束后的状态恢复

打字完成后执行：

```ts
if (currentIndex >= fullText.length) {
  clearInterval(this.typingTimer)
  this.typingTimer = -1
  this.isSending = false
}
```

这里做了三件事：

```text
1. clearInterval 停止定时器
2. typingTimer = -1 标记当前没有定时器
3. isSending = false 恢复输入框和发送按钮
```

发送按钮是这样控制的：

```ts
Button(this.isSending ? '发送中' : '发送')
  .enabled(!this.isSending)
```

输入框也是这样控制的：

```ts
.enabled(!this.isSending)
```

所以 `isSending = false` 后，用户就可以继续输入下一条消息了。

---

## 二十四、本次完整核心代码片段

### 1. 定时器变量

```ts
private typingTimer: number = -1
```

### 2. 生命周期清理

```ts
aboutToDisappear(): void {
  if (this.typingTimer !== -1) {
    clearInterval(this.typingTimer)
    this.typingTimer = -1
  }
}
```

### 3. 打字机回复

```ts
mockAskAi(question: string): void {
  const fullText: string = `你刚才说的是：${question}。这是一个模拟 AI 回复，当前正在使用打字机效果逐字输出。`

  const aiItem: ChatItem = {
    id: this.nextId++,
    type: 'ai',
    content: 'AI 正在思考...'
  }

  this.chatList = this.chatList.concat([aiItem])
  this.scrollToBottom()

  let currentIndex: number = 0

  setTimeout(() => {
    this.typingTimer = setInterval(() => {
      currentIndex++

      const currentText: string = fullText.slice(0, currentIndex)

      this.chatList = this.chatList.map((item: ChatItem) => {
        if (item.id === aiItem.id) {
          return {
            id: item.id,
            type: item.type,
            content: currentText
          }
        }

        return item
      })

      this.scrollToBottom()

      if (currentIndex >= fullText.length) {
        clearInterval(this.typingTimer)
        this.typingTimer = -1
        this.isSending = false
      }
    }, 60)
  }, 500)
}
```

### 4. ForEach key

```ts
ForEach(this.chatList, (item: ChatItem) => {
  ListItem() {
    Row() {
      if (item.type === 'user') {
        Blank()

        Text(item.content)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#1677FF')
          .borderRadius(10)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      } else {
        Text(item.content)
          .fontSize(16)
          .fontColor('#333333')
          .backgroundColor(Color.White)
          .borderRadius(10)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })

        Blank()
      }
    }
    .width('100%')
    .margin({ bottom: 12 })
  }
}, (item: ChatItem) => `${item.id}-${item.content}`)
```

---

## 二十五、本次知识点总结

本次练习涉及以下知识点：

1. `setTimeout` 模拟 AI 思考延迟
2. `setInterval` 实现逐字输出
3. `clearInterval` 清理定时器
4. `slice` 截取字符串
5. `concat` 追加数组元素
6. `map` 更新数组中的指定元素
7. `@Local` 响应式状态
8. `ForEach` 列表渲染
9. `ForEach` 的 key 对刷新有影响
10. `aboutToDisappear` 生命周期清理
11. `Scroller` 控制列表滚动
12. `scrollToIndex` 滚动到指定列表项
13. `isSending` 控制发送中状态

---

## 二十六、本次踩坑总结

### 问题一：AI 消息初始内容为空，看起来像没反应

最开始写的是：

```ts
content: ''
```

页面上看起来没有明显反馈。

改成：

```ts
content: 'AI 正在思考...'
```

这样用户点击发送后，能立刻看到 AI 状态。

### 问题二：保留了额外的 loading ListItem，逻辑混乱

之前同时存在：

```text
chatList 里的 AI 消息
isSending 额外渲染的“AI 正在思考...”
```

后来统一改成：

```text
所有消息都放进 chatList
```

这样结构更清晰。

### 问题三：定时器在执行，但页面没有刷新

原因是：

```ts
}, (item: ChatItem) => item.id.toString())
```

key 只使用了 `id`。

但是打字机更新时：

```text
id 不变
content 变化
```

所以页面可能复用原来的列表项，没有稳定刷新。

最终改成：

```ts
}, (item: ChatItem) => `${item.id}-${item.content}`)
```

让 `content` 变化也参与 key 计算。

---

## 二十七、表达

这个功能可以这样说：

> 我在聊天 Demo 中实现了 AI 回复的打字机输出效果。实现思路是用户发送消息后，先把用户消息追加到消息数组，然后创建一条 AI 消息，初始内容显示“AI 正在思考...”。延迟一小段时间后，通过 setInterval 定时器不断增加 currentIndex，再用 slice 从完整回复中截取当前要展示的文本。每次截取后，通过 map 找到对应的 AI 消息并更新它的 content。
>
> 这次还遇到了一个刷新问题：ForEach 的 key 一开始只用了 id，但打字机过程中消息 id 不变，只是 content 不断变化，页面没有稳定刷新。后来我把 key 改成 id + content，让 content 变化也能影响列表项识别，最终解决了页面不刷新的问题。
>
> 同时我也在 aboutToDisappear 生命周期中清理 setInterval，避免页面销毁后定时器还在执行。

---

## 二十八、本次 Git 流程

### 1. 创建功能分支

```bash
git checkout ai-chat
git pull origin ai-chat
git checkout -b feature/chat-typewriter-reply
```

### 2. 开发功能

修改：

```text
entry/src/main/ets/pages/Setting.ets
```

新增：

```text
docs/02-chat-typewriter-reply.md
```

### 3. 提交功能分支

```bash
git status
git add entry/src/main/ets/pages/Setting.ets docs/02-chat-typewriter-reply.md
git commit -m "feat: add typewriter reply effect"
git push origin feature/chat-typewriter-reply
```

### 4. 创建 PR

GitHub 上创建 PR：

```text
base: ai-chat
compare: feature/chat-typewriter-reply
```

PR 标题：

```text
feat: add typewriter reply effect
```

PR 描述：

```md
## 本次改动

- 新增 AI 回复打字机输出效果
- 使用 setTimeout 模拟 AI 思考延迟
- 使用 setInterval 逐字输出回复内容
- 使用 map 更新指定 AI 消息
- 修复 ForEach key 只使用 id 导致内容更新不刷新的问题
- 页面销毁时清理定时器

## 涉及文件

- entry/src/main/ets/pages/Setting.ets
- docs/02-chat-typewriter-reply.md

## 学习点

- setTimeout
- setInterval
- clearInterval
- slice
- map
- concat
- ForEach key
- aboutToDisappear
- Scroller
```

### 5. 合并 PR 后同步本地

```bash
git checkout ai-chat
git pull origin ai-chat
git branch -d feature/chat-typewriter-reply
git status
```

---

## 二十九、本次练习总结

这次练习最重要的收获有三个。

第一个是打字机效果的本质：

```text
完整文本 fullText
  ↓
定时器不断增加 currentIndex
  ↓
slice 截取越来越长的文本
  ↓
更新 AI 消息 content
  ↓
页面显示逐字输出
```

第二个是数组更新方式：

```text
新增消息：concat
更新消息：map
```

第三个是 ForEach 的 key 很重要：

```text
如果 key 只和 id 有关，而页面变化主要发生在 content 上，
那么页面可能不会稳定刷新。
```

所以本次解决方案是：

```ts
}, (item: ChatItem) => `${item.id}-${item.content}`)
```

这次功能完成后，聊天 Demo 已经从普通消息追加，升级成了一个更像 AI 聊天应用的基础交互效果。