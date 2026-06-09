# AI 聊天从纯文本到结构化卡片：SSE done 帧携带 card + 历史记录卡片恢复实战

> 项目：`Harmony Chat Demo`  
> 分支：`ai-chat`  
> 提交：`f63914c`  
> 主题：后端添加新的打车回复逻辑，前端根据后端返回 `type` 字段判断是否需要把回复渲染成卡片，并持久化 `card` 数据，保证历史记录也能恢复卡片样式。

---

## 一、这次提交解决了什么问题？

之前 AI 聊天模块的回复形态比较单一：

```text
后端 SSE chunk 一段段吐文本
        ↓
前端 activeAiMessage.content += chunk
        ↓
ChatListComp 按普通 Text 气泡展示
        ↓
会话结束后只保存 content
```

这种模式适合普通问答，但如果要做类似打车、酒店、外卖、订单确认这种业务场景，单纯文本就不够了。

比如用户输入：

```text
打车
```

后端希望返回两部分内容：

```text
1. 上方仍然是 AI 文本说明：
   目的地已为你选择香港国际机场，推荐上车点为香港会展中心……

2. 下方追加一个结构化卡片：
   确认上车点
   - 香港西九龙站
   - 高铁西九龙站(K出口)
   - 查看更多
```

所以这次提交的核心目标就是：

```text
文本继续走 SSE chunk 流式输出；
结构化卡片不跟着 chunk 一起流，而是在 done 帧一次性返回；
前端收到 done.card 后，把当前 AI 消息切到“文本 + 卡片”展示；
保存历史记录时也保存 card；
下次打开历史会话时，还能恢复同样的卡片 UI。
```

一句话总结：**把聊天消息从“只有 content 的纯文本模型”，升级成了“content + card 的复合消息模型”。**

---

## 二、整体链路图

这次改动看起来文件不少，但链路很清晰：

```text
用户输入“打车”
   ↓
server/app/api/chat/route.ts
   ↓
判断 isTaxiIntent(inputContent)
   ↓
chunk 帧：逐字返回 TAXI_INTRO 文案
   ↓
done 帧：返回 sessionId / messageId / card
   ↓
common/SseHttpUtil 解析 done 帧并透传 card
   ↓
ChatController.onDone(meta)
   ↓
activeAiMessage.card = meta.card
   ↓
ChatListComp 判断 msg.card !== null
   ↓
渲染 PickupConfirmCardComp
   ↓
ChatSessionController 持久化 content + card
   ↓
历史记录恢复时 convertToObservable 重新赋值 msg.card
   ↓
历史会话也展示卡片
```

对应文件：

| 文件 | 作用 |
|---|---|
| `server/app/api/chat/route.ts` | 新增打车意图判断、`TAXI_INTRO`、`TAXI_CARD`，在 done 帧下发 `card` |
| `common/src/main/ets/utils/SseHttpUtil.ets` | `SseDoneMeta` 新增 `card?: Object`，解析 done 帧时透传 |
| `chat/src/main/ets/models/chatModel.ets` | 新增 `PickupPoint`、`PickupCard`，并给 `ChatMessage` / `ChatMessagePlain` 增加 `card` 字段 |
| `chat/src/main/ets/controller/ChatController.ets` | 在 `onDone` 中把 `meta.card` 赋给当前 AI 消息 |
| `chat/src/main/ets/components/ChatListComp.ets` | assistant 消息从单纯 Text 改成 Column，文本下方可追加卡片 |
| `chat/src/main/ets/components/PickupConfirmCardComp.ets` | 新增“确认上车点”票据风格卡片组件 |
| `chat/src/main/ets/controller/ChatSessionController.ets` | `ChatMessage ↔ ChatMessagePlain` 转换时保留 `card` |
| `chat/src/main/resources/base/media/location.png` | 卡片左侧轴使用的地图图标 |

---

## 三、后端：把“打车”识别成特殊业务场景

### 3.1 新增打车文案和卡片数据

后端新增了两类数据：

```typescript
const TAXI_INTRO = '目的地已为你选择香港国际机场，推荐上车点为香港会展中心，该点附近存在多个点位或管控严格，请确认上车点。'
```

这个文案仍然走原来的 SSE chunk 流式推送，所以前端可以继续保留打字机效果。

卡片数据单独定义成结构化对象：

```typescript
interface PickupPoint {
  index: number
  name: string
  address: string
  distance: string
  entrance?: string
}

interface PickupCard {
  type: 'pickup_confirm'
  title: string
  question: string
  currentLocation: string
  points: PickupPoint[]
  moreText: string
}
```

`type` 是这里最关键的字段。现在只有 `pickup_confirm`，但后面可以继续扩展：

```text
pickup_confirm       确认上车点卡片
hotel_confirm        酒店确认卡片
order_confirm        订单确认卡片
coupon_list          优惠券列表卡片
product_recommend    商品推荐卡片
```

这也是为什么不要只用 `card !== null` 做长期设计，后续更稳的写法应该是：

```typescript
if (this.msg.card?.type === 'pickup_confirm') {
  PickupConfirmCardComp({ card: this.msg.card! })
}
```

这次提交已经在模型里保留了 `type` 字段，后续扩展卡片种类会比较自然。

### 3.2 用 isTaxiIntent 判断是否走打车逻辑

后端新增：

```typescript
function isTaxiIntent(input: string): boolean {
  return input.trim() === '打车' || input.includes('打车')
}
```

然后在接口里判断：

```typescript
const taxi = isTaxiIntent(inputContent)

let replyContent: string
if (taxi) {
  replyContent = TAXI_INTRO
} else {
  const baseReply = MOCK_REPLIES[Math.floor(Math.random() * MOCK_REPLIES.length)]
  replyContent = currentTurn > 1
    ? `（第 ${currentTurn} 轮 · 我记得前面聊过 ${userCount} 个问题）\n\n${baseReply}`
    : baseReply
}
```

也就是说：

```text
普通问题：继续随机 mock 文案
打车问题：固定返回 TAXI_INTRO
```

这里还有一个点：原来的多轮上下文逻辑没有被删掉，只是在非打车场景继续保留。

### 3.3 card 不放在 chunk 帧，而是放在 done 帧

服务端推流时仍然逐字返回：

```typescript
for (const ch of replyContent) {
  const frame: SseFrame = { chunk: ch, done: false }
  controller.enqueue(encoder.encode(`data: ${JSON.stringify(frame)}\n\n`))
  await sleep(50)
}
```

等文本输出完成，再构造结束帧：

```typescript
const endFrame: SseFrame = {
  done: true,
  sessionId: finalSessionId,
  messageId
}

if (taxi) {
  endFrame.card = TAXI_CARD
}

controller.enqueue(encoder.encode(`data: ${JSON.stringify(endFrame)}\n\n`))
```

这个设计很重要。

如果把 card 跟 chunk 混在一起，会出现几个问题：

```text
1. card 是完整结构，不需要一个字段一个字段流式展示；
2. chunk 主要负责 content 追加，职责应该保持单纯；
3. done 帧本来就负责告诉前端“这条消息结束了”，很适合顺带下发 messageId、sessionId、card 这类最终元信息；
4. 前端只有拿到完整 card 后再渲染，避免半截卡片数据导致 UI 异常。
```

所以最终协议变成：

```text
普通 chunk 帧：
{ "chunk": "目", "done": false }
{ "chunk": "的", "done": false }
{ "chunk": "地", "done": false }

结束 done 帧：
{
  "done": true,
  "sessionId": "xxx",
  "messageId": "xxx",
  "card": {
    "type": "pickup_confirm",
    "title": "确认上车点",
    "points": []
  }
}
```

---

## 四、common 层：SSE 工具只负责透传，不关心业务卡片类型

`common/src/main/ets/utils/SseHttpUtil.ets` 里改了 `SseDoneMeta`：

```typescript
export interface SseDoneMeta {
  sessionId?: string
  messageId?: string
  error?: string
  card?: Object
}
```

这里没有直接引入 `PickupCard`，而是用 `Object`。

这个选择是对的，因为 `SseHttpUtil` 在 `common` 模块里，它是通用网络层工具，不应该认识 chat 模块里的业务模型。

更合理的分层是：

```text
common/SseHttpUtil
只知道 SSE 协议：chunk / done / sessionId / messageId / error / card Object

chat/ChatController
知道业务模型：PickupCard、ChatMessage、ChatViewModel
```

解析 done 帧时，直接把 `frame.card` 透传出去：

```typescript
if (frame.done === true) {
  doneFired = true
  callbacks.onDone({
    sessionId: frame.sessionId,
    messageId: frame.messageId,
    error: frame.error,
    card: frame.card
  })
}
```

这就完成了从服务端 done 帧到业务 Controller 的桥接。

---

## 五、模型层：ChatMessage 新增 card 字段

### 5.1 新增 PickupPoint / PickupCard

`chatModel.ets` 新增两个模型：

```typescript
export class PickupPoint {
  index: number = 0
  name: string = ''
  address: string = ''
  distance: string = ''
  entrance: string = ''
}

export class PickupCard {
  type: string = ''
  title: string = ''
  question: string = ''
  currentLocation: string = ''
  points: PickupPoint[] = []
  moreText: string = ''
}
```

这两个类的特点是：只有字段，没有方法。

这会影响后面的历史恢复逻辑。因为 `JSON.parse` 回来的对象不是 `PickupCard` 实例，而是 plain object。但只要没有方法，只做字段读取，运行时使用上基本没有差异。

### 5.2 ChatMessage：UI 响应用

原来的消息模型大概是：

```typescript
@ObservedV2
export class ChatMessage {
  id: string = ''
  role: string = ''
  @Trace content: string = ''
  createTime: number = 0
  sessionId: string = ''
}
```

这次增加：

```typescript
@Trace card: PickupCard | null = null
```

为什么加 `@Trace`？

因为 card 是在 `onDone` 才赋值的，而不是创建 AI 占位消息时就有。

流程是：

```text
sendMessage 创建空 AI 消息
   ↓
AI 消息 push 到 historyMessage
   ↓
chunk 不断更新 content
   ↓
done 帧回来
   ↓
activeAiMessage.card = meta.card
   ↓
MessageBubble 需要重新 build，展示卡片
```

如果 `card` 不是响应式字段，赋值后 UI 可能不会自动刷新。所以这里加 `@Trace` 是必要的。

### 5.3 ChatMessagePlain：持久化用

持久化模型也增加：

```typescript
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
  card: PickupCard | null = null
}
```

这个字段决定了历史会话能不能恢复卡片。

如果只给 `ChatMessage` 加 `card`，不改 `ChatMessagePlain`，会出现：

```text
当前会话能看到卡片
   ↓
退出页面或重新打开历史
   ↓
只恢复 content
   ↓
card 丢失
   ↓
历史记录退化成普通文本
```

所以真正完整的改动必须同时覆盖：

```text
运行时模型 ChatMessage
持久化模型 ChatMessagePlain
运行时 → 持久化 convertToPlain
持久化 → 运行时 convertToObservable
```

---

## 六、Controller：在 onDone 里把 card 挂到当前 AI 消息上

`ChatController.ets` 原本在 `onDone` 里主要做三件事：

```text
1. 更新 sessionId
2. 更新 messageId
3. 结束 loading，清空 activeAiMessage/currentRequest
```

这次在清理状态之前加了 card 赋值：

```typescript
if (meta.card && this.activeAiMessage) {
  this.activeAiMessage.card = meta.card as Object as PickupCard
}
```

为什么一定要在 `activeAiMessage = null` 前面做？

因为当前正在生成的 AI 消息，就是列表里那条 assistant 消息的引用：

```text
const aiMessage = new ChatMessage()
this.vm.historyMessage.push(aiMessage)
this.activeAiMessage = aiMessage
```

也就是说：

```text
activeAiMessage
和
historyMessage 里的最后一条 assistant 消息
是同一个对象
```

所以只要：

```typescript
this.activeAiMessage.card = xxx
```

列表里的那条消息也就有了 `card`，UI 会因为 `@Trace card` 重新渲染。

完整链路可以理解成：

```text
SSE done meta.card
   ↓
ChatController.onDone
   ↓
activeAiMessage.card
   ↓
historyMessage[i].card
   ↓
MessageBubble.msg.card
   ↓
PickupConfirmCardComp
```

这里没有新建一条“卡片消息”，而是让同一条 assistant 消息同时包含：

```text
content：AI 文案
card：结构化卡片
```

这个设计比“文本一条消息 + 卡片一条消息”更适合当前场景，因为它们本来就是同一次 AI 回复的两个展示层。

---

## 七、列表渲染：assistant 消息从 Text 气泡升级成 Column

### 7.1 原来的 assistant 渲染

原来 assistant 消息就是一个文本气泡：

```typescript
Text(this.getAssistantText())
  .fontSize(15)
  .fontColor(this.theme.textPrimary)
  .padding(12)
  .backgroundColor(this.theme.assistantBubbleBg)
  .borderRadius({ ... })
  .constraintSize({ maxWidth: '75%' })
```

这种写法没有空间放卡片。

### 7.2 新的 assistant 渲染

这次改成：

```typescript
Column({ space: 8 }) {
  Text(this.getAssistantText())
    .fontSize(15)
    .fontColor(this.theme.textPrimary)
    .constraintSize({ maxWidth: '85%' })

  if (this.msg.card !== null) {
    PickupConfirmCardComp({ card: this.msg.card! })
  }
}
.alignItems(HorizontalAlign.Start)
```

这里有两个变化。

第一个变化是结构从 `Text` 变成 `Column`：

```text
Column
 ├─ Text：AI 文案
 └─ PickupConfirmCardComp：可选卡片
```

第二个变化是 AI 文本不再使用气泡背景：

```text
无气泡背景
无圆角
无 padding
直接展示在列表背景上
```

这样卡片展示会更像主流 App 的智能助手回复：上面是一段解释文字，下面是一张业务卡片，而不是把卡片塞进一个聊天气泡里。

### 7.3 当前判断逻辑和后续扩展建议

当前代码是：

```typescript
if (this.msg.card !== null) {
  PickupConfirmCardComp({ card: this.msg.card! })
}
```

对于现在只有一种卡片的阶段完全够用。

但既然模型里已经有 `type`，后续建议改成：

```typescript
if (this.msg.card?.type === 'pickup_confirm') {
  PickupConfirmCardComp({ card: this.msg.card! })
}
```

如果将来有多种卡片，可以封装一个统一入口：

```typescript
@Builder
buildAssistantCard(card: PickupCard) {
  if (card.type === 'pickup_confirm') {
    PickupConfirmCardComp({ card })
  }
}
```

再往后甚至可以抽象成：

```text
ChatCardRenderer
  ├─ PickupConfirmCardComp
  ├─ OrderConfirmCardComp
  ├─ ProductRecommendCardComp
  └─ CouponListCardComp
```

这样聊天列表就不用关心具体卡片实现。

---

## 八、PickupConfirmCardComp：票据风格卡片怎么搭出来？

这次新增的 `PickupConfirmCardComp.ets` 是一个完整卡片组件，整体结构是：

```text
Column 白底卡片
 ├─ Header 渐变区域
 │   ├─ 标题：确认上车点 + 黄色底条
 │   └─ 左侧轴：? - 虚线 - 地图图标
 ├─ TicketDivider：水平虚线 + 左右半圆挖洞
 ├─ List：上车点列表
 │   ├─ 序号
 │   ├─ 名称
 │   ├─ 地址
 │   ├─ 距离
 │   └─ 第一项额外展示进站口按钮
 └─ Footer：查看更多按钮
```

### 8.1 卡片根容器

根容器使用：

```typescript
.width('100%')
.backgroundColor('#FFFFFF')
.borderRadius(16)
.clip(true)
.constraintSize({ maxWidth: '92%' })
```

几个点：

```text
backgroundColor('#FFFFFF')：卡片主体白底
borderRadius(16)：圆角票据感
clip(true)：配合后面的半圆凹口
maxWidth: '92%'：避免卡片顶满整个列表宽度
```

其中 `clip(true)` 很关键。

### 8.2 票据凹口：用 Circle + offset + clip 实现

组件里有一个 `TicketDivider()`：

```typescript
@Builder
TicketDivider() {
  Stack({ alignContent: Alignment.Center }) {
    Line()
      .height(1)
      .startPoint([0, 0])
      .endPoint([1000, 0])
      .stroke(this.theme.divider)
      .strokeWidth(1)
      .strokeDashArray([4, 4])
      .width('100%')
      .margin({ left: 12, right: 12 })

    Row() {
      Circle({ width: PickupConfirmCardComp.NOTCH_D, height: PickupConfirmCardComp.NOTCH_D })
        .fill(this.theme.bg)
        .offset({ x: -PickupConfirmCardComp.NOTCH_D / 2, y: 0 })

      Blank()

      Circle({ width: PickupConfirmCardComp.NOTCH_D, height: PickupConfirmCardComp.NOTCH_D })
        .fill(this.theme.bg)
        .offset({ x: PickupConfirmCardComp.NOTCH_D / 2, y: 0 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
  .width('100%')
  .height(PickupConfirmCardComp.NOTCH_D)
}
```

原理是：

```text
1. 中间先画一条水平虚线；
2. 左右各放一个 Circle；
3. Circle 的圆心通过 offset 移到卡片边缘；
4. Circle 的颜色设置成列表背景色 theme.bg；
5. 外层卡片 clip(true)，把超出卡片外的半圆裁掉；
6. 视觉上就像白色票据被“挖”出了两个半圆缺口。
```

这是一种很实用的 ArkUI 小技巧：**没有直接的“挖洞”API，也可以用同色圆 + 裁剪模拟。**

### 8.3 左侧轴：问号、虚线、地图图标

左侧轴封装成 `LeftAxis()`：

```text
Column
 ├─ Text('?')：圆形边框
 ├─ Line：纵向虚线
 └─ Image(location)：地图图标
```

代码中统一用：

```typescript
private static readonly AXIS_SEG: number = 14
```

让三个元素高度对齐，避免 header 里文字和轴线错位。

### 8.4 上车点列表：ForEach + ListItem

卡片中部使用：

```typescript
List({ space: 4 }) {
  ForEach(this.card.points, (p: PickupPoint, idx: number) => {
    ListItem() {
      this.buildPointItem(p, idx === 0)
    }
  }, (p: PickupPoint) => p.index + '_' + p.name)
}
```

这里的 key 是：

```typescript
p.index + '_' + p.name
```

这样即使列表刷新，ArkUI 也能尽量复用已有节点。

第一项如果有 `entrance`，额外展示“进站口”按钮：

```typescript
if (isFirst && p.entrance) {
  Row({ space: 8 }) {
    Text(p.entrance)
    Column({ space: 3 }) {
      Row().width(14).height(2)
      Row().width(14).height(2)
      Row().width(14).height(2)
    }
  }
}
```

这个细节让卡片更接近真实打车 App 的上车点选择样式。

---

## 九、历史持久化：为什么 card 要跟着 ChatMessagePlain 走？

这次另一个重点是：**历史记录也要展示卡片样式。**

如果只做当前会话渲染，链路到 `ChatListComp` 就结束了。但一旦用户打开历史记录，数据来源就变了：

```text
当前会话：内存里的 ChatMessage[]
历史会话：Preferences 里的 ChatSession / ChatMessagePlain[]
```

所以要让历史会话恢复卡片，必须在两个转换函数里都处理 `card`。

### 9.1 保存：ChatMessage → ChatMessagePlain

`convertToPlain()` 新增：

```typescript
plain.card = source.card ? source.card : null
```

完整逻辑变成：

```typescript
private convertToPlain(): ChatMessagePlain[] {
  return this.vm.historyMessage.map((source: ChatMessage, i: number) => {
    const plain = new ChatMessagePlain()
    plain.id = source.id ? source.id : `${this.vm.sessionId}_${i}`
    plain.role = source.role ? source.role : 'assistant'
    plain.content = source.content ? source.content : ''
    plain.createTime = source.createTime ? source.createTime : Date.now()
    plain.sessionId = source.sessionId ? source.sessionId : this.vm.sessionId
    plain.card = source.card ? source.card : null
    return plain
  })
}
```

这一步负责把运行时响应式对象转成普通对象，方便 `JSON.stringify`。

### 9.2 恢复：ChatMessagePlain → ChatMessage

`convertToObservable()` 新增：

```typescript
msg.card = plain.card ? plain.card : null
```

完整逻辑变成：

```typescript
private convertToObservable(plains: ChatMessagePlain[], sessionId: string): ChatMessage[] {
  return plains.map((plain: ChatMessagePlain, i: number) => {
    const msg = new ChatMessage()
    msg.id = plain.id ? plain.id : `${sessionId}_${i}`
    msg.role = plain.role ? plain.role : 'assistant'
    msg.content = plain.content ? plain.content : ''
    msg.createTime = plain.createTime ? plain.createTime : Date.now()
    msg.sessionId = plain.sessionId ? plain.sessionId : sessionId
    msg.card = plain.card ? plain.card : null
    return msg
  })
}
```

这一步负责把普通对象重新转成 `@ObservedV2` 的 `ChatMessage`，让 UI 继续具备响应式能力。

### 9.3 为什么不用重新 new PickupCard？

代码注释里也写到了：

```text
JSON.parse 出来的 plain.card 是普通对象，字段与 PickupCard 一致，
直接赋值即可（PickupCard 上无方法，无需重建实例）
```

这句话的前提是：

```text
PickupCard / PickupPoint 只有字段，没有方法。
```

如果后续给 `PickupCard` 加了方法，比如：

```typescript
class PickupCard {
  formatDistance(): string { ... }
}
```

那 JSON 恢复后直接赋值就不够了，需要手动重建：

```typescript
const card = new PickupCard()
card.type = plain.card.type
card.title = plain.card.title
...
msg.card = card
```

当前版本不需要这么做，直接字段访问足够。

---

## 十、这次提交里最值得记住的几个设计点

### 10.1 chunk 和 done 的职责分离

这次没有把 card 拆成 chunk，而是放在 done 帧里一次性返回。

```text
chunk：只负责流式文本

done：负责最终元信息
      - sessionId
      - messageId
      - card
      - error
```

这个协议设计很干净，前端也更容易处理。

### 10.2 common 层不依赖业务模型

`SseHttpUtil` 只写：

```typescript
card?: Object
```

没有从 chat 模块 import `PickupCard`。

这避免了 common 和 chat 之间反向依赖，也让 SSE 工具可以继续复用到别的业务场景。

### 10.3 一条 assistant 消息承载文本和卡片

没有新建单独的 card 消息，而是在 `ChatMessage` 上加：

```typescript
content: string
card: PickupCard | null
```

这种结构更适合“一次 AI 回复由文本解释 + 业务卡片组成”的场景。

### 10.4 持久化不能只保存 content

历史记录要恢复卡片，就必须保存完整消息结构：

```text
id
role
content
createTime
sessionId
card
```

否则当前会话看得到，历史会话就会丢。

### 10.5 @Trace 不只用于文本，也可以用于结构化字段

`content` 用 `@Trace` 是为了流式刷新文本。

`card` 用 `@Trace` 是为了 done 帧回来后刷新卡片。

```typescript
@Trace content: string = ''
@Trace card: PickupCard | null = null
```

这也是 ArkTS 响应式模型里很关键的一点：**后赋值、需要驱动 UI 的字段，也要进入响应式追踪。**

---

## 十一、可以继续优化的地方

### 11.1 根据 type 做卡片分发

当前：

```typescript
if (this.msg.card !== null) {
  PickupConfirmCardComp({ card: this.msg.card! })
}
```

建议后续改成：

```typescript
if (this.msg.card?.type === 'pickup_confirm') {
  PickupConfirmCardComp({ card: this.msg.card! })
}
```

再进一步抽成统一渲染器：

```typescript
@ComponentV2
export struct ChatCardRenderer {
  @Param @Require card: PickupCard

  build() {
    if (this.card.type === 'pickup_confirm') {
      PickupConfirmCardComp({ card: this.card })
    } else {
      Text('暂不支持的卡片类型')
    }
  }
}
```

### 11.2 把 PickupCard 升级成通用 ChatCard

现在模型叫 `PickupCard`，如果未来只有打车卡片没问题。

但如果后面要接入更多卡片，可以改成：

```typescript
export class ChatCard {
  type: string = ''
  payload: Object | null = null
}
```

或者：

```typescript
export class ChatMessage {
  content: string = ''
  cardType: string = ''
  cardData: Object | null = null
}
```

这样 chat 模块不会被某一个业务卡片绑定死。

### 11.3 卡片点击事件还没有闭环

现在卡片只是展示：

```text
确认上车点
查看更多
进站口按钮
```

但还没有处理点击。

后续可以加：

```text
点击某个上车点 → 选中态
点击“查看更多” → 展开更多 points 或跳转上车点选择页
点击“确认上车点” → 发送下一轮消息给后端
```

这时卡片组件可以暴露回调：

```typescript
@Event onSelectPoint: (point: PickupPoint) => void = () => {}
@Event onMore: () => void = () => {}
```

### 11.4 服务端意图判断可以更细

当前：

```typescript
return input.trim() === '打车' || input.includes('打车')
```

这只是 demo 级判断。后续可以扩展成：

```text
“我要去机场”
“帮我叫车”
“从会展中心到机场”
“打个车去香港国际机场”
```

都识别为打车场景。

---

## 十二、最终效果回顾

用户输入：

```text
打车
```

后端先流式返回：

```text
目的地已为你选择香港国际机场，推荐上车点为香港会展中心，该点附近存在多个点位或管控严格，请确认上车点。
```

文本输出完成后，done 帧额外带上：

```json
{
  "type": "pickup_confirm",
  "title": "确认上车点",
  "question": "您在哪里上车?",
  "currentLocation": "香港中国企业协会",
  "points": [
    {
      "index": 1,
      "name": "香港西九龙站",
      "address": "香港特别行政区油尖旺区柯士甸道西3号",
      "distance": "65.9km",
      "entrance": "进站口1"
    }
  ],
  "moreText": "查看更多"
}
```

前端收到后，当前 assistant 消息变成：

```text
ChatMessage
 ├─ content: 打车说明文案
 └─ card: PickupCard
```

列表展示时变成：

```text
AI 文案

┌───────────────────────┐
│ 确认上车点              │
│ 您在哪里上车?           │
│ 香港中国企业协会         │
│ - 香港西九龙站 65.9km   │
│ - 高铁西九龙站 65.9km   │
│ 查看更多                │
└───────────────────────┘
```

保存历史记录时，`content` 和 `card` 一起写入 `ChatMessagePlain`。

恢复历史记录时，`plain.card` 重新赋值给 `ChatMessage.card`，因此历史记录也能展示同样的卡片样式。

---

## 十三、给将来的自己：这类需求的通用套路

以后如果再做“AI 回复里混合业务卡片”的需求，可以直接套这个模式：

```text
1. 服务端定义 card schema，并加 type 字段；
2. 文本解释继续走 SSE chunk；
3. card 放到 done 帧一次性返回；
4. SSE 工具层只透传 Object，不依赖具体业务；
5. 业务 Controller 把 meta.card 映射到消息模型；
6. 消息模型同时包含 content 和 card；
7. UI 根据 card.type 分发到不同卡片组件；
8. 持久化模型也保存 card；
9. 历史恢复时把 card 重新挂回响应式消息。
```

记住一句话：

> 流式的是文本，结构化的是结果；文本进 `content`，结果进 `card`，历史保存两者，UI 根据 `type` 分发。

这就是这次提交最核心的工程价值。
