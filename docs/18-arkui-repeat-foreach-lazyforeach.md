# HarmonyOS 6.0 ArkUI 循环渲染：ForEach、LazyForEach 和 Repeat 到底怎么选？

> 适合发布平台：掘金 / CSDN / 个人技术博客  
> 面向读者：刚开始做 HarmonyOS / ArkUI / ArkTS UI 开发的同学  
> 核心结论：**HarmonyOS 6.0 新项目里，循环渲染优先考虑 Repeat。短列表用 Repeat 普通模式，长列表用 Repeat + virtualScroll；ForEach 更适合简单小数组或旧代码，LazyForEach 更像旧版长列表懒加载方案。**

---

## 1. 前言：循环渲染不是“把数组遍历出来”这么简单

在 ArkUI 声明式 UI 里，我们经常会遇到这种需求：

- 聊天消息列表：一条一条消息往下排；
- 订单列表：每个订单一张卡片；
- 搜索结果页：几十到几千条数据；
- 首页信息流：普通文本、图片卡片、营销卡片混合出现；
- 打车、外卖、AI 回复这类业务里，后端返回 `type` 字段，前端根据类型渲染不同样式。

刚开始写的时候，很多人会自然想到：

```ts
ForEach(this.list, item => {
  Text(item.title)
})
```

这当然能跑，但是列表一旦变长、结构变复杂、数据频繁刷新，就会遇到性能和状态问题。

HarmonyOS ArkUI 里常见的循环渲染方式主要有三个：

1. `ForEach`：最基础的数组循环渲染。
2. `LazyForEach`：通过数据源 `IDataSource` 做懒加载。
3. `Repeat`：更现代的可复用循环渲染能力，既能覆盖普通循环，也能通过 `virtualScroll` 覆盖长列表懒加载场景。

这篇文章就用通俗方式讲清楚：**它们分别解决什么问题、有什么区别、为什么新代码更推荐默认用 Repeat。**

---

## 2. 先给结论：默认用 Repeat，但不是所有场景都默认开 virtualScroll

很多同学听到“Repeat 更强”，容易理解成：以后所有列表都直接 `Repeat + virtualScroll`。

这不完全对。

更准确的选择方式应该是：

| 场景 | 推荐写法 | 原因 |
| --- | --- | --- |
| 少量固定数据，比如标签、菜单、3~20 个元素 | `Repeat` 普通模式 | 写法简洁，后续也容易升级 |
| 普通业务列表，比如订单、聊天、搜索结果 | `Repeat + key` | 比 ForEach 更适合增删改移动场景 |
| 长列表、大数据、滚动性能敏感 | `Repeat + virtualScroll` | 按需创建，并可结合复用能力 |
| 老项目里已经封装了 `IDataSource` | 继续 `LazyForEach` 或迁移到 `Repeat` | 看迁移成本 |
| 只是学习语法、写小 demo | `ForEach` 也可以 | 简单直接，但不要滥用到长列表 |

一句话总结：

> **HarmonyOS 6.0 写新列表时，优先从 Repeat 开始。数据少就普通 Repeat，数据多再加 virtualScroll。**

---

## 3. ForEach：最容易上手，但它更像“全量循环渲染”

`ForEach` 是很多人接触 ArkUI 循环渲染时最先学到的语法。它的心智模型非常简单：

> 给我一个数组，我把数组里的每一项都生成一个 UI 节点。

示例：

```ts
class MenuItemModel {
  id: string = ''
  title: string = ''

  constructor(id: string, title: string) {
    this.id = id
    this.title = title
  }
}

@Entry
@Component
struct ForEachDemoPage {
  @State menus: MenuItemModel[] = [
    new MenuItemModel('home', '首页'),
    new MenuItemModel('message', '消息'),
    new MenuItemModel('profile', '我的')
  ]

  build() {
    Column({ space: 12 }) {
      ForEach(
        this.menus,
        (item: MenuItemModel) => {
          Row() {
            Text(item.title)
              .fontSize(16)
          }
          .width('100%')
          .padding(12)
        },
        (item: MenuItemModel) => item.id
      )
    }
    .padding(16)
  }
}
```

这个例子里有三个关键点：

- 第一个参数：数组 `this.menus`；
- 第二个参数：每一项如何生成 UI；
- 第三个参数：`keyGenerator`，也就是每一项的唯一标识。

### 3.1 ForEach 的优点

`ForEach` 的优点很明显：

- 写法简单；
- 学习成本低；
- 很适合小数组；
- 非滚动场景也能直接用，比如一排按钮、一组标签、一组设置项。

比如下面这种标签列表，用 `ForEach` 完全可以：

```ts
Row({ space: 8 }) {
  ForEach(
    this.tags,
    (tag: string) => {
      Text(tag)
        .fontSize(12)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(12)
        .backgroundColor('#F2F3F5')
    },
    (tag: string) => tag
  )
}
```

### 3.2 ForEach 的问题

但是 `ForEach` 不适合无脑套到所有列表上。

因为它更偏向“全量渲染”。假设你有 10000 条聊天记录，用 `ForEach` 一次性生成 10000 个列表项，哪怕用户屏幕上只看到十几条，框架也要处理大量节点。

这会带来几个问题：

1. 首屏压力大；
2. 内存占用高；
3. 数据频繁增删改时，UI 更新成本变高；
4. 如果 `key` 写得不稳定，容易出现列表项错乱、状态串位、刷新异常。

所以，`ForEach` 更适合“小而简单”的循环渲染。

### 3.3 ForEach 里最容易踩的坑：拿 index 当 key

很多初学者会这样写：

```ts
ForEach(
  this.messages,
  (item: MessageModel) => {
    MessageItem({ item: item })
  },
  (_item: MessageModel, index: number) => index.toString()
)
```

这看起来没问题，但一旦列表发生插入、删除、排序，就很危险。

比如原来列表是：

```text
0 -> A
1 -> B
2 -> C
```

如果你在最前面插入一条新消息 X，列表变成：

```text
0 -> X
1 -> A
2 -> B
3 -> C
```

这时候原来的 A、B、C 的 index 都变了。框架会认为它们的身份也变了，可能导致组件复用、刷新和状态对应关系出现问题。

更好的方式是让后端或本地模型提供稳定 ID：

```ts
ForEach(
  this.messages,
  (item: MessageModel) => {
    MessageItem({ item: item })
  },
  (item: MessageModel) => item.id
)
```

口诀：

> **key 表示“这一项是谁”，不是“这一项现在排第几个”。**

---

## 4. LazyForEach：为长列表而生，但代码成本更高

`LazyForEach` 的出现，是为了解决 `ForEach` 全量渲染的问题。

它的核心思想是：

> 不要一次性把所有子组件都创建出来，而是根据滚动容器的可视区域按需创建。

也就是说，用户当前只能看到 10 条，那就优先创建可见区域附近的节点；用户往下滑，再继续按需创建后面的节点。

这对于长列表很有价值。

### 4.1 LazyForEach 的基本形态

`LazyForEach` 不是直接接收普通数组，而是接收一个实现了 `IDataSource` 的数据源对象。

简化版结构大概是这样：

```ts
class BasicDataSource<T> implements IDataSource {
  private listeners: DataChangeListener[] = []
  private dataArray: T[] = []

  public totalCount(): number {
    return this.dataArray.length
  }

  public getData(index: number): T {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  public pushData(item: T): void {
    this.dataArray.push(item)
    const index = this.dataArray.length - 1
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(index)
    })
  }

  public updateData(index: number, item: T): void {
    this.dataArray[index] = item
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index)
    })
  }
}
```

然后在 UI 里使用：

```ts
List() {
  LazyForEach(
    this.messageSource,
    (item: MessageModel) => {
      ListItem() {
        MessageItem({ item: item })
      }
    },
    (item: MessageModel) => item.id
  )
}
```

> 注意：不同 SDK 版本里 `DataChangeListener` 的方法名可能有新增、废弃或兼容形式，实际项目以当前 DevEco Studio 类型提示和官方 API Reference 为准。这里重点看 LazyForEach 的设计思想：它通过数据源和监听器驱动 UI 更新。

### 4.2 LazyForEach 的优点

`LazyForEach` 的优点是：

- 适合大数据量列表；
- 首屏不会一次性创建全部组件；
- 可以通过数据源通知局部刷新；
- 适合 `List`、`Grid`、`Swiper`、`WaterFlow` 这类滚动/滑动容器。

如果你要做商品瀑布流、长聊天列表、新闻流，`LazyForEach` 的按需加载思路就比 `ForEach` 更合理。

### 4.3 LazyForEach 的问题

但 `LazyForEach` 的缺点也很明显：**样板代码比较重。**

你不能只是写一个数组：

```ts
this.messages: MessageModel[]
```

而是要准备数据源类、监听器、增删改通知方法。

对于新手来说，经常会遇到这些问题：

1. 数据改了，但是忘记调用 `onDataChange`，UI 不刷新；
2. 插入数据后 index 通知错了，列表显示异常；
3. `keyGenerator` 不稳定，导致节点重建或状态错乱；
4. 业务代码被数据源封装撑得比较复杂；
5. 后续要做多类型卡片时，代码会更绕。

所以在 HarmonyOS 6.0 新项目里，如果不是维护历史 `LazyForEach` 代码，很多场景更适合直接使用 `Repeat`。

---

## 5. Repeat：新项目更推荐的循环渲染方式

`Repeat` 可以理解成 ArkUI 对循环渲染的一次升级。

它的优势在于：

- 可以像 `ForEach` 一样直接基于数组渲染；
- 可以通过 `virtualScroll` 做长列表按需渲染；
- 支持 `template` / `templateId`，更适合多类型列表；
- API 相比 `LazyForEach` 更清爽，不需要一上来就写 `IDataSource`；
- 在部分更新和复用场景里更友好。

也就是说，`Repeat` 可以同时覆盖两类需求：

```text
小列表：Repeat ≈ 更现代的 ForEach
长列表：Repeat + virtualScroll ≈ 更现代的 LazyForEach
```

这也是为什么我认为：**HarmonyOS 6.0 新项目里，默认用 Repeat 是比较稳的选择。**

---

## 6. Repeat 普通模式：替代 ForEach 的日常写法

先看最简单的写法。

```ts
class TaskModel {
  id: string = ''
  title: string = ''

  constructor(id: string, title: string) {
    this.id = id
    this.title = title
  }
}

@Entry
@ComponentV2
struct RepeatNormalPage {
  @Local tasks: TaskModel[] = [
    new TaskModel('1', '学习 ArkUI 声明式 UI'),
    new TaskModel('2', '掌握循环渲染'),
    new TaskModel('3', '使用 Repeat 重构列表')
  ]

  build() {
    Column({ space: 12 }) {
      Repeat<TaskModel>(this.tasks)
        .each((obj: RepeatItem<TaskModel>) => {
          Row() {
            Text(`${obj.index + 1}.`)
              .fontSize(14)
              .fontColor('#86909C')
              .margin({ right: 8 })

            Text(obj.item.title)
              .fontSize(16)
              .fontColor('#1D2129')
          }
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor('#F7F8FA')
        })
        .key((item: TaskModel) => item.id)
    }
    .padding(16)
  }
}
```

和 `ForEach` 相比，`Repeat` 有一个明显变化：

```ts
.each((obj: RepeatItem<TaskModel>) => {
  // obj.item  是当前数据
  // obj.index 是当前索引
})
```

`RepeatItem` 把 `item` 和 `index` 包在一起，由框架侧维护索引。这种写法在列表局部更新、移动、复用时更清晰。

### 6.1 each 是必填项

`Repeat` 里 `.each()` 是必须写的。

你可以把它理解成默认渲染模板：

```ts
Repeat<TaskModel>(this.tasks)
  .each((obj: RepeatItem<TaskModel>) => {
    Text(obj.item.title)
  })
```

如果后面配置了 `template` / `templateId`，没有匹配到模板的数据项，也会走 `.each()` 这个默认渲染逻辑。

### 6.2 key 依然非常重要

`Repeat` 也要写稳定 key：

```ts
.key((item: TaskModel) => item.id)
```

不要偷懒写 index：

```ts
// 不推荐
.key((_item: TaskModel, index: number) => index.toString())
```

因为只要发生插入、删除、排序，index 就会变化。

稳定 key 的优先级建议是：

1. 后端返回的业务 ID；
2. 本地生成后持久化的 UUID；
3. 数据创建时间戳 + 业务类型组合；
4. 实在没有 ID，才考虑 index，但只适合永不插入、删除、排序的静态数组。

---

## 7. Repeat + virtualScroll：长列表就这么写

当列表数据很多，或者列表项比较复杂时，就可以给 `Repeat` 加上 `virtualScroll`。

示例：

```ts
class MessageModel {
  id: string = ''
  content: string = ''

  constructor(id: string, content: string) {
    this.id = id
    this.content = content
  }
}

@Entry
@ComponentV2
struct RepeatVirtualScrollPage {
  @Local messages: MessageModel[] = []

  aboutToAppear(): void {
    for (let i = 0; i < 1000; i++) {
      this.messages.push(new MessageModel(`${i}`, `第 ${i + 1} 条消息`))
    }
  }

  build() {
    List({ space: 8 }) {
      Repeat<MessageModel>(this.messages)
        .each((obj: RepeatItem<MessageModel>) => {
          ListItem() {
            Text(obj.item.content)
              .fontSize(16)
              .padding(12)
              .width('100%')
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
          }
        })
        .key((item: MessageModel) => item.id)
        .virtualScroll({
          totalCount: this.messages.length
        })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#F2F3F5')
    .cachedCount(2)
  }
}
```

这段代码里有几个关键点：

1. `Repeat` 仍然基于数组 `this.messages`；
2. `List` 里每次生成的是 `ListItem`；
3. `.virtualScroll()` 开启虚拟滚动；
4. `totalCount` 表示数据总量；
5. `List().cachedCount(2)` 可以给列表预加载一点缓存，避免滑动时太生硬；
6. `.key()` 仍然要稳定。

### 7.1 普通 Repeat 和 virtualScroll Repeat 的区别

可以这样理解：

```text
Repeat 普通模式：数组有多少项，就按普通循环渲染多少项。
Repeat + virtualScroll：只按滚动容器可视范围和缓存范围创建需要的项。
```

所以短列表不一定要开 `virtualScroll`，否则反而让代码变复杂。

我的经验是：

- 20 条以内：普通 `Repeat`；
- 20~100 条：普通 `Repeat` 或 `Repeat + virtualScroll` 都可以，看列表项复杂度；
- 100 条以上、列表项复杂、图片多、卡片多：优先 `Repeat + virtualScroll`；
- 无限滚动、分页加载、信息流：优先 `Repeat + virtualScroll`，必要时结合懒加载回调。

---

## 8. Repeat 最适合的业务场景：根据 type 渲染不同卡片

这块很适合放到 AI 聊天、打车、订单确认这类业务里。

比如后端返回消息时，不只是返回文本，还会返回一个 `type`：

```ts
class ChatMessageModel {
  id: string = ''
  type: string = ''
  content: string = ''

  constructor(id: string, type: string, content: string) {
    this.id = id
    this.type = type
    this.content = content
  }
}
```

可能的类型有：

```text
text          普通文本消息
pickup_card   打车确认卡片
order_card    订单卡片
image         图片消息
```

如果用 `if/else` 写在一个巨大组件里，后面会越来越难维护。

`Repeat` 的 `template` / `templateId` 很适合处理这种多类型列表。

```ts
@Entry
@ComponentV2
struct ChatRepeatPage {
  @Local messages: ChatMessageModel[] = [
    new ChatMessageModel('1', 'text', '你好，我想去深圳北站'),
    new ChatMessageModel('2', 'pickup_card', '已为你生成打车确认卡片'),
    new ChatMessageModel('3', 'text', '请确认出发地和目的地')
  ]

  build() {
    List({ space: 12 }) {
      Repeat<ChatMessageModel>(this.messages)
        .each((obj: RepeatItem<ChatMessageModel>) => {
          // 默认兜底模板：未知类型就按普通文本展示，避免白屏
          ListItem() {
            Text(obj.item.content)
              .fontSize(15)
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
          }
        })
        .key((item: ChatMessageModel) => item.id)
        .virtualScroll({ totalCount: this.messages.length })
        .template('text', (obj: RepeatItem<ChatMessageModel>) => {
          ListItem() {
            Text(obj.item.content)
              .fontSize(15)
              .fontColor('#1D2129')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
          }
        })
        .template('pickup_card', (obj: RepeatItem<ChatMessageModel>) => {
          ListItem() {
            Column({ space: 8 }) {
              Text('打车确认')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)

              Text(obj.item.content)
                .fontSize(14)
                .fontColor('#4E5969')

              Button('确认叫车')
                .width('100%')
            }
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
          }
        })
        .templateId((item: ChatMessageModel) => item.type)
    }
    .padding(12)
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }
}
```

这个例子很接近真实业务：

- 后端通过 `type` 告诉前端渲染什么类型；
- 前端通过 `templateId` 选择模板；
- 普通文本走 `text` 模板；
- 打车确认走 `pickup_card` 模板；
- 未知类型走 `.each()` 兜底，避免页面挂掉；
- 历史记录只要持久化了 `type` 和对应数据，重新进入页面也能恢复卡片样式。

这也是我认为 `Repeat` 比 `ForEach` 更适合复杂业务列表的原因：

> 它不是只帮你“循环数组”，而是帮你管理“列表项身份、复用、模板和长列表性能”。

---

## 9. ForEach、LazyForEach、Repeat 的核心区别

可以用一张表记住：

| 对比项 | ForEach | LazyForEach | Repeat |
| --- | --- | --- | --- |
| 数据源 | 普通数组 | `IDataSource` | 普通数组 / RepeatArray |
| 学习成本 | 低 | 高 | 中等 |
| 小列表 | 可以 | 不太必要 | 推荐 |
| 长列表 | 不推荐 | 可以 | 推荐 `virtualScroll` |
| 是否需要数据源封装 | 不需要 | 需要 | 通常不需要 |
| 多类型模板 | 靠 if/else | 靠 if/else 或组件拆分 | 支持 `template` / `templateId` |
| 复用能力 | 弱 | 偏懒加载 | 更适合复用循环渲染 |
| 新项目推荐度 | 一般 | 维护旧代码可用 | 高 |

更通俗一点：

```text
ForEach：我把数组全都画出来。
LazyForEach：我通过数据源按需拿数据来画。
Repeat：我基于数组来画，需要时还能按需画、复用画、多模板画。
```

---

## 10. 为什么我建议“默认用 Repeat”

### 10.1 第一，Repeat 从简单场景开始就不复杂

短列表场景下，`Repeat` 的代码并不比 `ForEach` 难太多：

```ts
Repeat<string>(this.names)
  .each((obj: RepeatItem<string>) => {
    Text(obj.item)
  })
  .key((item: string) => item)
```

你只要接受 `obj.item` 和 `obj.index` 这种写法，很快就能上手。

### 10.2 第二，后续升级成本低

今天你只是 10 条数据：

```ts
Repeat<MessageModel>(this.messages)
  .each(...)
  .key(...)
```

明天变成 1000 条，你可以继续加：

```ts
.virtualScroll({ totalCount: this.messages.length })
```

后天消息类型变多，你还能继续加：

```ts
.template('text', ...)
.template('pickup_card', ...)
.templateId((item) => item.type)
```

这比一开始写 `ForEach`，后来再整体迁移到 `LazyForEach` 或复杂模板，要平滑得多。

### 10.3 第三，Repeat 更贴近真实业务

真实业务列表很少永远只是：

```text
一条数据 -> 一个 Text
```

更多时候是：

```text
一条文本消息 -> 文本气泡
一条打车回复 -> 打车卡片
一条订单回复 -> 订单卡片
一条图片消息 -> 图片预览
一条错误消息 -> 错误提示
```

这类场景非常适合用 `Repeat + templateId`。

### 10.4 第四，LazyForEach 的数据源代码对新手不友好

`LazyForEach` 本身不是不好，而是它的样板代码比较多。

如果你只是想渲染一个数组，却必须先封装 `IDataSource`、写监听器、写通知方法，新手很容易把注意力放到“怎么让它刷新”上，而不是业务本身。

`Repeat` 对新项目更友好，因为它可以从普通数组开始。

---

## 11. 从 LazyForEach 迁移到 Repeat 的思路

如果你维护的是旧代码，可能已经有这种写法：

```ts
List() {
  LazyForEach(
    this.messageSource,
    (item: MessageModel) => {
      ListItem() {
        MessageItem({ item: item })
      }
    },
    (item: MessageModel) => item.id
  )
}
```

迁移到 `Repeat` 的关键是：

1. 把 `IDataSource` 里的真实数组拿出来；
2. 用 `Repeat<T>(array)` 替代 `LazyForEach(dataSource)`；
3. `itemGenerator` 改成 `.each()`；
4. `keyGenerator` 改成 `.key()`；
5. 长列表加 `.virtualScroll()`；
6. 多类型列表用 `.template()` 和 `.templateId()` 拆出来。

迁移后的代码可能是：

```ts
List() {
  Repeat<MessageModel>(this.messages)
    .each((obj: RepeatItem<MessageModel>) => {
      ListItem() {
        MessageItem({ item: obj.item })
      }
    })
    .key((item: MessageModel) => item.id)
    .virtualScroll({ totalCount: this.messages.length })
}
```

如果业务里原来有分页加载，也可以继续保留分页逻辑，只是 UI 层不一定再依赖 `IDataSource`。

---

## 12. 实战建议：聊天列表/AI 回复列表怎么写

如果你正在写一个 AI 聊天 demo，后端可能返回：

```json
{
  "id": "msg_1001",
  "role": "assistant",
  "type": "pickup_card",
  "content": "已为你生成打车方案",
  "card": {
    "from": "公司",
    "to": "深圳北站",
    "price": "约 35 元"
  }
}
```

前端不要只存 `content`，应该把这些字段都存下来：

```ts
class ChatMessageEntity {
  id: string = ''
  role: string = ''
  type: string = ''
  content: string = ''
  cardJson: string = ''
}
```

原因是：

- 当前页面渲染需要 `type` 判断卡片；
- 历史记录恢复也需要 `type` 和 `card` 数据；
- 如果只存文本，下一次进入页面就只能显示普通气泡，卡片样式丢失；
- `Repeat + templateId` 可以很自然地根据 `type` 恢复不同模板。

推荐结构：

```ts
List() {
  Repeat<ChatMessageEntity>(this.messageList)
    .each((obj: RepeatItem<ChatMessageEntity>) => {
      ListItem() {
        Text(obj.item.content)
      }
    })
    .key((item: ChatMessageEntity) => item.id)
    .virtualScroll({ totalCount: this.messageList.length })
    .template('text', (obj: RepeatItem<ChatMessageEntity>) => {
      ListItem() {
        TextMessageBubble({ message: obj.item })
      }
    })
    .template('pickup_card', (obj: RepeatItem<ChatMessageEntity>) => {
      ListItem() {
        PickupConfirmCard({ message: obj.item })
      }
    })
    .templateId((item: ChatMessageEntity) => item.type)
}
```

这样做的好处是：

1. 新增卡片类型时，只要新增 template；
2. 普通消息和卡片消息不会混在一个巨大 if/else 里；
3. 后端新增 `type` 时，前端扩展点清晰；
4. 历史记录恢复时，仍然能按原样渲染；
5. 列表变长后，可以继续依靠 `virtualScroll` 控制性能。

---

## 13. 常见误区和避坑清单

### 13.1 误区一：数据少也必须用 LazyForEach

不需要。

如果只是 10 个菜单、20 个标签、几个设置项，用 `LazyForEach` 反而让代码变复杂。

更推荐：

```text
短列表：Repeat 普通模式
长列表：Repeat + virtualScroll
旧长列表：LazyForEach 可继续维护，逐步迁移 Repeat
```

### 13.2 误区二：Repeat 一定要开 virtualScroll

也不需要。

`virtualScroll` 是为长列表和滚动性能准备的。短列表普通 `Repeat` 就够了。

### 13.3 误区三：key 随便写一个就行

不行。

`key` 是列表项身份。要稳定、唯一、可持久。

推荐：

```ts
.key((item: MessageModel) => item.id)
```

不推荐：

```ts
.key((_item: MessageModel, index: number) => index.toString())
```

### 13.4 误区四：List 里面生成普通 Row 就行

在 `List` 里循环渲染时，通常每一项应该生成 `ListItem`。

推荐：

```ts
List() {
  Repeat<MessageModel>(this.messages)
    .each((obj: RepeatItem<MessageModel>) => {
      ListItem() {
        MessageItem({ item: obj.item })
      }
    })
}
```

不要在 `List` 下随意生成父容器不支持的子组件。

### 13.5 误区五：历史记录只存 content

如果你的消息会根据 `type` 渲染成卡片，持久化时就不能只存 `content`。

应该至少保存：

```text
id
role
type
content
card 数据
createTime
```

否则历史记录恢复时无法知道这条消息原本是不是卡片。

---

## 14. 我的推荐写法模板

### 14.1 小列表模板

```ts
Repeat<ItemModel>(this.items)
  .each((obj: RepeatItem<ItemModel>) => {
    Text(obj.item.title)
  })
  .key((item: ItemModel) => item.id)
```

### 14.2 长列表模板

```ts
List() {
  Repeat<ItemModel>(this.items)
    .each((obj: RepeatItem<ItemModel>) => {
      ListItem() {
        ItemCard({ item: obj.item })
      }
    })
    .key((item: ItemModel) => item.id)
    .virtualScroll({ totalCount: this.items.length })
}
.cachedCount(2)
```

### 14.3 多类型卡片模板

```ts
List() {
  Repeat<MessageModel>(this.messages)
    .each((obj: RepeatItem<MessageModel>) => {
      ListItem() {
        Text(obj.item.content)
      }
    })
    .key((item: MessageModel) => item.id)
    .virtualScroll({ totalCount: this.messages.length })
    .template('text', (obj: RepeatItem<MessageModel>) => {
      ListItem() {
        TextMessage({ message: obj.item })
      }
    })
    .template('card', (obj: RepeatItem<MessageModel>) => {
      ListItem() {
        BusinessCard({ message: obj.item })
      }
    })
    .templateId((item: MessageModel) => item.type)
}
```

---

## 15. 总结

最后再把选择逻辑压缩成一句话：

> **ForEach 适合小而简单的全量循环；LazyForEach 适合旧版长列表懒加载；Repeat 更适合 HarmonyOS 6.0 新项目，短列表用普通 Repeat，长列表用 Repeat + virtualScroll，多类型业务列表用 Repeat + templateId。**

如果你是刚入门 ArkUI，我建议你这样学：

1. 先理解 `ForEach`，知道它是怎么把数组渲染成 UI 的；
2. 再理解 `LazyForEach`，知道长列表为什么不能一次性全量渲染；
3. 最后把日常开发习惯切到 `Repeat`，以后写列表默认先想它。

尤其是在 AI 聊天、打车卡片、订单卡片这种“后端返回 type，前端按类型渲染”的场景里，`Repeat` 的模板能力会让代码结构更清晰，也更方便做历史记录恢复。

---

## 参考资料

- Huawei Developer：ForEach：循环渲染  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-foreach

- Huawei Developer：LazyForEach：数据懒加载  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach

- Huawei Developer：Repeat：可复用的循环渲染  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-rendering-control-repeat

- Huawei Developer：LazyForEach 迁移 Repeat 指南  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-lazyforeach-repeat-migration-guide

- Huawei Developer：Repeat API Reference  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-rendering-control-repeat
