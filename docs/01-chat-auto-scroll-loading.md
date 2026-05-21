# 鸿蒙聊天 Demo 练习 01：发送消息、模拟 AI 回复与自动滚动

## 一、本次分支

```bash
feature/chat-auto-scroll-loading
```

## 二、本次目标

本次在聊天 Demo 的基础页面上，完善了一个最小可用的聊天流程：

1. 用户输入消息
2. 点击发送
3. 消息追加到聊天数组
4. 模拟 AI 延迟回复
5. 消息列表自动滚动到底部
6. 发送期间禁用输入框和按钮，避免重复发送

## 三、涉及文件

```text
entry/src/main/ets/pages/Setting.ets
```

## 四、页面结构

当前聊天页面分为三部分：

```text
Column
├── Header       顶部标题栏
├── MessageList  中间消息列表
└── InputBar     底部输入栏
```

对应代码：

```ts
build() {
  Column() {
    this.Header()
    this.MessageList()
    this.InputBar()
  }
}
```

这种结构非常适合聊天页面：

- 顶部固定标题
- 中间区域使用 `layoutWeight(1)` 占据剩余空间
- 底部输入框固定在页面底部

## 五、消息数据结构

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
| id | 唯一标识，用于 `ForEach` 的 key |
| type | 区分用户消息和 AI 消息 |
| content | 消息文本内容 |

## 六、为什么消息数组使用 concat

发送消息时使用：

```ts
this.chatList = this.chatList.concat([userItem])
```

而不是：

```ts
this.chatList.push(userItem)
```

原因是 `concat` 会返回一个新数组，更容易触发 ArkUI 的状态更新。

简单理解：

```text
push：修改原数组
concat：生成新数组，然后重新赋值
```

在响应式 UI 中，重新赋值通常更稳定。

## 七、Scroller 的作用

本次用到了：

```ts
private listScroller: Scroller = new Scroller()
```

然后绑定到 `List`：

```ts
List({ scroller: this.listScroller }) {
  ...
}
```

这样就可以通过代码控制列表滚动：

```ts
this.listScroller.scrollToIndex(this.chatList.length)
```

## 八、为什么滚动到底部要用 setTimeout

消息数组更新后，UI 不一定立刻渲染完成。

如果马上滚动，可能会出现滚动不到最新消息的问题。

所以封装了一个方法：

```ts
scrollToBottom(): void {
  setTimeout(() => {
    this.listScroller.scrollToIndex(this.chatList.length)
  }, 50)
}
```

逻辑是：

```text
先更新数组
等待 UI 刷新
再滚动到底部
```

## 九、为什么滚动索引是 chatList.length

`List` 中除了消息列表，还有一个底部占位项：

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

刚好可以滚到最后的底部占位项。

## 十、模拟 AI 回复

本次没有真正调用接口，而是使用 `setTimeout` 模拟异步请求：

```ts
mockAskAi(question: string): void {
  setTimeout(() => {
    const aiItem: ChatItem = {
      id: this.nextId++,
      type: 'ai',
      content: `你刚才说的是：${question}`
    }

    this.chatList = this.chatList.concat([aiItem])
    this.isSending = false
    this.scrollToBottom()
  }, 600)
}
```

以后真正接接口时，可以把 `setTimeout` 替换成网络请求。

## 十一、发送中状态

定义状态：

```ts
@Local isSending: boolean = false
```

发送时：

```ts
this.isSending = true
```

AI 回复完成后：

```ts
this.isSending = false
```

按钮根据状态变化：

```ts
Button(this.isSending ? '发送中' : '发送')
  .enabled(!this.isSending)
```

输入框也可以禁用：

```ts
.enabled(!this.isSending)
```

## 十二、本次知识点总结

本次练习涉及以下鸿蒙开发知识点：

1. `@ComponentV2` 组件写法
2. `@Local` 本地响应式状态
3. `Column / Row / List / ListItem / TextInput / Button`
4. `ForEach` 渲染数组
5. `Scroller` 控制列表滚动
6. `scrollToIndex` 滚动到指定位置
7. `setTimeout` 处理 UI 渲染后的延迟滚动
8. `KeyboardAvoidMode.RESIZE` 处理键盘顶起页面
9. 使用 `concat` 更新数组，保证状态刷新
10. 使用 `isSending` 控制按钮禁用和加载状态

## 十三、面试表达

这个功能可以这样说：

> 我在聊天 Demo 中实现了基础的消息发送和模拟 AI 回复流程。页面采用上中下布局，中间使用 `List` 渲染消息数组，底部使用 `TextInput` 和 `Button` 处理输入。为了保证发送消息后能自动看到最新内容，我创建了 `Scroller` 实例并绑定到 `List`，在消息数组更新后通过 `scrollToIndex` 滚动到底部。同时考虑到 UI 渲染存在时序问题，所以封装了 `scrollToBottom` 方法，用 `setTimeout` 延迟滚动，保证列表刷新后再执行滚动。另外我还加入了 `isSending` 状态，模拟接口请求期间禁用输入和按钮，避免重复发送。

## 十四、本次提交命令

```bash
git add entry/src/main/ets/pages/Setting.ets docs/01-chat-auto-scroll-loading.md

git commit -m "feat: add chat auto scroll and loading state"

git push origin feature/chat-auto-scroll-loading
```

## 十五、本次练习总结

这一小节的重点不是聊天功能本身，而是理解一个聊天页面最基础的状态流转：

```text
用户输入
  ↓
点击发送
  ↓
追加用户消息
  ↓
模拟请求中状态
  ↓
追加 AI 回复
  ↓
滚动到底部
```

这套流程后面可以继续扩展成：

- 打字机输出
- 真实接口请求
- 本地历史记录
- 会话列表
- 消息组件拆分
- 输入框聚焦和键盘处理