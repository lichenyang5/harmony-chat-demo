# 补充：Repeat 虚拟滚动与 cachedCount 到底怎么用

上一篇我们已经讲了 `ForEach`、`LazyForEach` 和 `Repeat` 的区别，也给出了一个结论：在 HarmonyOS 6.0 的新项目里，列表渲染可以优先考虑 `Repeat`。

但是在实际写聊天列表、商品列表、卡片流的时候，很容易把两个概念搞混：

- `Repeat.virtualScroll()`
- `List.cachedCount()`
- `Repeat.template(..., { cachedCount })`

这几个名字里都出现了“虚拟滚动”“缓存”“懒加载”这些词，但它们负责的事情并不一样。

这篇补充就专门把这个点讲清楚。

---

## 一、先说结论：Repeat 不直接负责“上下预加载几条”

如果你想实现这样的效果：

> 当前屏幕最多展示 6 条数据，希望用户滚动时，屏幕上方和下方附近可以提前准备 3 条，减少快速滚动时的白屏和卡顿。

正确思路不是只写 `Repeat.template(..., { cachedCount: 3 })`，而是：

```ts
List() {
  Repeat<Message>(this.messageList)
    .virtualScroll({ totalCount: this.messageList.length })
    .key((item: Message) => item.id)
    .each((ri: RepeatItem<Message>) => {
      ListItem() {
        MessageItem({ message: ri.item })
      }
    })
}
.cachedCount(3)
```

这里真正控制“可视区域外预加载”的是：

```ts
.cachedCount(3)
```

也就是 `List` 的 `cachedCount`，不是 `Repeat.template` 的 `cachedCount`。

可以简单记成一句话：

> `Repeat.virtualScroll()` 负责开启虚拟滚动；`List.cachedCount()` 负责可视区域外预加载；`Repeat.template(..., { cachedCount })` 负责模板节点复用缓存池。

---

## 二、`.virtualScroll()` 做了什么

先看这段代码：

```ts
Repeat<Message>(this.messageList)
  .virtualScroll({ totalCount: this.messageList.length })
```

它的意思是：

> 开启 `Repeat` 的虚拟滚动模式，让列表不要一次性创建所有 item，而是根据滚动容器的可视区域，按需创建和复用 UI 节点。

也就是说，如果你的聊天列表有 1000 条消息，它不会一开始就把 1000 个 UI 节点全部创建出来。

更准确的理解是：

```txt
屏幕内的数据：需要渲染
屏幕附近的数据：可能会根据缓存策略提前渲染
离屏幕很远的数据：不会提前创建 UI 节点
```

所以不要把 `virtualScroll` 理解成“只渲染屏幕内 6 条”。

更准确的说法是：

> `virtualScroll` 会让 `Repeat` 按可视区域附近的数据进行懒加载和节点复用，而不是全量渲染整个数组。

---

## 三、`List.cachedCount(3)` 才是预加载附近 item

假设现在一个页面最多展示 6 条消息，每条消息高度大约是 `72vp`，希望上下附近额外预加载 3 条，可以这样写：

```ts
interface Message {
  id: string
  type: string
  content: string
}

@ComponentV2
struct ChatListDemo {
  @Local messageList: Message[] = [
    { id: '1', type: 'text', content: '第一条消息' },
    { id: '2', type: 'text', content: '第二条消息' },
    { id: '3', type: 'text', content: '第三条消息' },
    { id: '4', type: 'text', content: '第四条消息' },
    { id: '5', type: 'text', content: '第五条消息' },
    { id: '6', type: 'text', content: '第六条消息' },
    { id: '7', type: 'text', content: '第七条消息' },
    { id: '8', type: 'text', content: '第八条消息' },
    { id: '9', type: 'text', content: '第九条消息' },
    { id: '10', type: 'text', content: '第十条消息' }
  ]

  build() {
    List() {
      Repeat<Message>(this.messageList)
        .virtualScroll({
          totalCount: this.messageList.length
        })
        .key((item: Message) => item.id)
        .each((ri: RepeatItem<Message>) => {
          ListItem() {
            Row() {
              Text(ri.item.content)
                .fontSize(16)
                .fontColor('#222222')
            }
            .width('100%')
            .height(72)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#FFFFFF')
          }
        })
    }
    .width('100%')
    .height(72 * 6) // 一屏大约展示 6 条
    .cachedCount(3) // 可视区域外额外预加载附近 item
  }
}
```

这段代码里有两个关键点。

第一个关键点是：

```ts
.virtualScroll({ totalCount: this.messageList.length })
```

它负责开启虚拟滚动。

第二个关键点是：

```ts
.cachedCount(3)
```

它挂在 `List` 上，负责列表可视区域外的预加载数量。

---

## 四、`Repeat.template(..., { cachedCount })` 不是预加载上下几条

再看另一种写法：

```ts
.template('confirm_trip', (ri: RepeatItem<ChatMessage>) => {
  ListItem() {
    ConfirmTripCardComp({ card: ri.item.card })
  }
}, {
  cachedCount: 2
})
```

这里的 `cachedCount: 2` 很容易被误解成“屏幕外缓存 2 条卡片数据”。

其实不是。

它更准确的含义是：

> `confirm_trip` 这个模板类型最多缓存 2 个可复用的 UI 节点。

也就是说，它是模板复用层面的缓存池，不是列表可视区域外的预加载数量。

可以这样区分：

| 写法 | 控制什么 | 可以怎么理解 |
| --- | --- | --- |
| `Repeat.virtualScroll()` | 是否开启虚拟滚动 | 不一次性创建全部 item |
| `List.cachedCount(3)` | 可视区域外预加载 item | 屏幕附近多准备一些列表项 |
| `Repeat.template(..., { cachedCount: 2 })` | 某个模板的复用节点缓存池 | 某类模板最多保留几个可复用节点 |

所以，如果你的目标是“用户滚动时，上下附近提前加载 3 条”，应该写在 `List` 上：

```ts
List() {
  // Repeat ...
}
.cachedCount(3)
```

而不是只写：

```ts
.template('xxx', builder, { cachedCount: 3 })
```

---

## 五、多类型聊天消息里的完整写法

如果你的聊天列表里既有普通文本消息，又有确认打车卡片，可以这样组织：

```ts
interface TripCard {
  title: string
  startLocation: string
  endLocation: string
  distance: string
  duration: string
  priceRange: string
}

interface ChatMessage {
  id: string
  type: string
  content: string
  card?: TripCard
}

@ComponentV2
struct ChatListComp {
  @Param messages: ChatMessage[]

  build() {
    List() {
      Repeat<ChatMessage>(this.messages)
        .virtualScroll({
          totalCount: this.messages.length
        })
        .key((item: ChatMessage) => item.id)
        .templateId((item: ChatMessage) => {
          if (item.type === 'confirm_trip') {
            return 'confirm_trip'
          }
          return 'text'
        })
        .each((ri: RepeatItem<ChatMessage>) => {
          ListItem() {
            Text(ri.item.content)
              .fontSize(15)
              .fontColor('#222222')
              .padding(12)
          }
        })
        .template('confirm_trip', (ri: RepeatItem<ChatMessage>) => {
          ListItem() {
            if (ri.item.card) {
              ConfirmTripCardComp({
                card: ri.item.card
              })
            }
          }
        }, {
          cachedCount: 2
        })
    }
    .width('100%')
    .height('100%')
    .cachedCount(3)
  }
}
```

这段代码里有三层含义。

第一层：

```ts
.virtualScroll({ totalCount: this.messages.length })
```

开启虚拟滚动。

第二层：

```ts
.templateId((item: ChatMessage) => {
  if (item.type === 'confirm_trip') {
    return 'confirm_trip'
  }
  return 'text'
})
```

根据消息类型选择模板。普通文本走默认模板，确认打车消息走 `confirm_trip` 模板。

第三层：

```ts
.cachedCount(3)
```

挂在 `List` 上，表示可视区域外额外预加载附近列表项。

而这里：

```ts
.template('confirm_trip', ..., { cachedCount: 2 })
```

只是 `confirm_trip` 模板自己的节点复用缓存池，不是上下预加载 2 条。

---

## 六、结合聊天列表再理解一次

以聊天列表为例，假设当前屏幕能看到 6 条消息，列表总共有 100 条消息。

如果不做虚拟滚动，可能会倾向于一次性创建大量 UI 节点，数据量大时会影响性能。

使用 `Repeat.virtualScroll()` 后，系统会根据列表当前显示区域，按需创建附近的 UI 节点。

再加上：

```ts
List().cachedCount(3)
```

可以让滚动容器在可视区域外提前准备一些 item。

大致可以这样理解：

```txt
当前屏幕可见：约 6 条
屏幕附近预加载：由 List.cachedCount(3) 控制
离屏幕很远的数据：不会提前创建 UI 节点
滚动过程中：复用已经创建过的节点
```

不过要注意，实际运行时不一定永远严格等于“上面 3 条 + 下面 3 条”。

因为缓存分布还会受下面这些因素影响：

- 当前是否在列表顶部
- 当前是否在列表底部
- 用户滚动方向
- item 高度是否一致
- 外层容器布局
- 系统内部复用策略

所以在表达时不要说死：

> 一定是上面 3 条，下面 3 条。

更稳的说法是：

> 设置 `List.cachedCount(3)` 后，列表会在可视区域外额外预加载附近 item，减少滚动时的白屏和卡顿。

---

## 七、开发时最容易写错的地方

### 1. 只写了 `virtualScroll`，以为已经设置了缓存数量

错误理解：

```ts
Repeat<Message>(this.messageList)
  .virtualScroll({ totalCount: this.messageList.length })
```

然后以为它已经自动设置了“上下缓存 3 条”。

实际上，`virtualScroll` 只是开启虚拟滚动，不是设置上下缓存数量。

如果要控制可视区域外预加载数量，还要看外层滚动容器：

```ts
List() {
  // Repeat ...
}
.cachedCount(3)
```

### 2. 把 `template cachedCount` 当成列表预加载数量

错误理解：

```ts
.template('confirm_trip', builder, { cachedCount: 3 })
```

以为这代表“确认打车卡片在屏幕外预加载 3 条”。

实际上它表示的是：

> `confirm_trip` 模板类型最多缓存 3 个可复用节点。

### 3. 没有写稳定的 key

列表数据经常新增、删除、更新时，建议给 `Repeat` 配置稳定的 `key`：

```ts
.key((item: ChatMessage) => item.id)
```

这样系统在更新 UI 时更容易识别每条消息，减少不必要的重建。

聊天列表里不要用数组下标当核心身份标识，尤其是消息可能插入、删除、刷新时。

---

## 八、最终记忆口诀

最后用几句话记住就够了：

```txt
ForEach：小列表普通循环。
LazyForEach：老的大列表懒加载方案，写法偏重。
Repeat：新的统一循环渲染方案。
Repeat.virtualScroll：开启虚拟滚动。
List.cachedCount：控制可视区域外预加载 item。
Repeat.template cachedCount：控制某个模板类型的节点复用缓存池。
```

如果是 HarmonyOS 6.0 新项目里的聊天列表，我会优先这样写：

```ts
List() {
  Repeat<ChatMessage>(this.messages)
    .virtualScroll({ totalCount: this.messages.length })
    .key((item: ChatMessage) => item.id)
    .templateId((item: ChatMessage) => item.type)
    .each((ri: RepeatItem<ChatMessage>) => {
      ListItem() {
        TextMessageItem({ message: ri.item })
      }
    })
    .template('confirm_trip', (ri: RepeatItem<ChatMessage>) => {
      ListItem() {
        ConfirmTripCardComp({ card: ri.item.card })
      }
    }, { cachedCount: 2 })
}
.cachedCount(3)
```

这套写法的优势是：

- 列表不会全量渲染所有消息
- 可以根据 `type` 分发不同消息模板
- 滚动时可以预加载附近 item
- 复杂卡片模板可以复用节点
- 很适合 AI 聊天、订单卡片、商品流、通知流这类多类型列表场景

---

## 九、一句话总结

`Repeat` 负责循环渲染和虚拟滚动，`List.cachedCount` 负责可视区域外预加载，`Repeat.template cachedCount` 负责模板节点复用。想让聊天列表“当前屏幕 6 条、上下附近预加载 3 条”，核心写法就是：

```ts
List() {
  Repeat<Message>(this.messageList)
    .virtualScroll({ totalCount: this.messageList.length })
    .key((item: Message) => item.id)
    .each((ri: RepeatItem<Message>) => {
      ListItem() {
        MessageItem({ message: ri.item })
      }
    })
}
.cachedCount(3)
```
