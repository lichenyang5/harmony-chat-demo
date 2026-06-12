# 把消息状态存进数据库：加一列、给老库补列、读回时"归一化"

> 项目：`MyApplication`（AI 打车对话 demo）
> 目标文件：`chat/src/main/ets/utils/ChatRdb.ets` + `models/chatModel.ets` + `controller/ChatSessionController.ets`
> 一句话：状态三部曲收官篇。前两篇把消息状态做成了枚举、把推进编排干净了，这篇让状态**活过 App 重启** —— 给数据库表加一列、给老用户的库平滑补列、并解决一个反直觉的问题：**读回来时"思考中"该怎么显示？**

---

## 〇、一个你肯定遇到过的体验

聊到一半，AI 还在打字，你顺手把 App 划掉了。再打开，进到这条历史会话 —— 它应该显示成什么样？

- 还卡在"思考中"转圈？😵 那它要转到天荒地老，因为那个网络请求早随进程一起没了。
- 假装"正常完成"？也不对，它根本没答完。

**正确答案是：显示成"失败，可重试"。** 这件事说明一个道理 —— **有些状态是"过程态"，它压根不该被原样存回来。** 这篇就把"状态落库 + 读回"这条链路里的几个坑一次讲透。

> 📌 本篇默认你看过 [25-arkts-rdb-chat-persistence](./25-arkts-rdb-chat-persistence.md)：聊天记录已经从 Preferences 换成了关系型数据库（RDB），两张表 `chat_session` / `chat_message`。这篇是在那张 message 表上**加一列 `status`**。

---

## 一、状态存哪：单独一列，不要塞进 JSON

`chat_message` 表原本长这样（简化）：

```sql
CREATE TABLE chat_message (
  id TEXT PRIMARY KEY,
  session_id TEXT,
  role TEXT,
  content TEXT,
  create_time INTEGER,
  card_json TEXT          -- 卡片这种嵌套结构，塞 JSON 兜底
)
```

新来的 `status` 该塞进某个 JSON，还是单开一列？**单开一列。** 判断依据很简单：

| 字段 | 形态 | 存法 |
|---|---|---|
| `card`（卡片） | 嵌套对象、字段多变、几乎不参与查询 | JSON 字符串塞一列就好 |
| `status`（状态） | 单个枚举值、未来很可能要 `WHERE status = 'failed'` 查 | **独立成列**，能建索引、能过滤 |

> 💡 经验法则：**会被拿去 `WHERE` / `ORDER BY` 的字段，单独成列；只是整存整取的复杂结构，才打包成 JSON。** 状态属于前者 —— 哪怕现在用不上"查出所有失败消息"，给它一列也比将来从 JSON 里捞便宜得多。

加列后建表语句（新装用户直接就有这列，还给了默认值）：

```sql
CREATE TABLE IF NOT EXISTS chat_message (
  ...
  card_json TEXT,
  status TEXT NOT NULL DEFAULT 'done'   -- ← 新增
)
```

---

## 二、最容易栽的坑：`CREATE TABLE IF NOT EXISTS` 不会给老表加列

这是迁移里最反直觉的一点。你可能觉得："我在建表语句里加了 `status` 列，重新跑一遍 init 不就有了？"

**不会。** `CREATE TABLE IF NOT EXISTS` 的语义是"**表不存在才建**"。老用户的 `chat_message` 表早就存在了，这句话直接**整条跳过**，你新加的 `status` 列**根本不会生效**。结果就是：新装用户好好的，老用户一读 `status` 列就报"no such column"崩给你看。

给已存在的表加列，得用 `ALTER TABLE`：

```ts
const SQL_ALTER_ADD_STATUS = `
  ALTER TABLE chat_message ADD COLUMN status TEXT NOT NULL DEFAULT 'done'
`
```

这里有两个讲究：

1. **`DEFAULT 'done'` 会自动回填老数据。** SQLite 给已存在的表 `ADD COLUMN` 且带非空默认值时，会把所有老行的这列填成默认值。于是历史消息全部变成 `'done'`（终态），符合直觉 —— 历史里的消息当然都是"已完成"的。
2. **列已存在时 `ALTER` 会抛错**，所以要用 try/catch 吞掉，让整个操作**幂等**（跑一百遍结果一样）：

```ts
private static async ensureStatusColumn(): Promise<void> {
  if (ChatRdb.store === null) return
  try {
    await ChatRdb.store.executeSql(SQL_ALTER_ADD_STATUS)
    LogUtil.i(TAG, 'status column added (migrated old db)')
  } catch (_e) {
    // 列已存在（新库 / 已迁移过）—— 正常情况，静默
  }
}
```

> ⚠️ 注意这个 try/catch 要**单独包**，不能和建表的 try/catch 混在一起。否则"列已存在"这种再正常不过的情况会被当成 init 失败，日志天天报错、还可能误导你以为数据库挂了。

调用点接在建表之后：

```ts
await ChatRdb.store.executeSql(SQL_CREATE_MESSAGE)   // 新库：建表（已含 status）
await ChatRdb.store.executeSql(SQL_CREATE_INDEX)
await ChatRdb.ensureStatusColumn()                   // 老库：补列；新库：抛错被吞
```

新库走建表自带列、老库走 ALTER 补列，两条路殊途同归 —— 这就是一次最小可用的"数据库迁移"。

---

## 三、读回时"归一化"：过程态一律改写成失败

回到开头那个问题。`status` 这六个值里：

```text
终态（存了就该原样还原）：  DONE   STOPPED   FAILED
过程态（重启后不可能续上）：  SENDING   THINKING   STREAMING
```

`DONE / STOPPED / FAILED` 是**终态**，存进去什么样、读出来就什么样。但 `SENDING / THINKING / STREAMING` 是**过程态** —— 它们代表"有个网络请求正在进行"，而进程一旦被杀，那个请求就灰飞烟灭了，绝无可能在下次启动时自己接着跑。

所以**读回来时，任何过程态都要改写成 `FAILED`**，让用户看到一个"可以重试"的明确出口，而不是一个永远转圈的僵尸。这个动作叫**归一化（normalize）**。

我把它放在模型的"反序列化"方法里，保证任何读取路径都自动生效：

```ts
// chatModel.ets
export function isTerminal(s: MessageStatus): boolean {
  return s === MessageStatus.DONE || s === MessageStatus.STOPPED || s === MessageStatus.FAILED
}

static fromPlain(plain: ChatMessagePlain, sessionId: string, index: number): ChatMessage {
  const msg = new ChatMessage()
  // ...逐字段空值防御...
  const raw: MessageStatus = plain.status ? plain.status : MessageStatus.DONE
  msg.status = isTerminal(raw) ? raw : MessageStatus.FAILED   // ← 过程态归一化成 FAILED
  return msg
}
```

> 💡 正常情况下根本不会存进过程态 —— 因为我们是**流式结束（终态）才落库**的（见第五节）。但"App 在落库前就被杀"这种极端情况确实存在，归一化是给这种漏网之鱼兜底。**防御性代码的价值，就在于挡住那些"理论上不会发生"的情况。**

---

## 四、序列化下沉到模型：`fromPlain` / `toPlain`

上面那个 `fromPlain` 还顺带做了一次**架构上的小重构**。

[25 篇](./25-arkts-rdb-chat-persistence.md)里，"响应式对象 ↔ 纯数据对象"的来回转换是写在 Controller 里的两个私有方法（`convertToObservable` / `convertToPlain`）。但这套转换逻辑其实是**模型自己的事** —— 它最懂自己有哪些字段、哪个该兜底。放 Controller 里属于"职责放错了地方"。

于是这次把它下沉进 `ChatMessage` 本身：

```ts
@ObservedV2
export class ChatMessage {
  @Trace content: string = ''
  @Trace status: MessageStatus = MessageStatus.DONE
  // ...

  /** 纯数据 → 响应式（读库时用，含空值防御 + 过程态归一化） */
  static fromPlain(plain: ChatMessagePlain, sessionId: string, index: number): ChatMessage { /* ... */ }

  /** 响应式 → 纯数据（写库时用） */
  toPlain(sessionId: string, index: number): ChatMessagePlain { /* ... */ }
}
```

Controller 一下子清爽了，只剩"调度"，不再手写映射：

```ts
// 读：纯数据 → 响应式
this.vm.historyMessage = sourceMessages.map(
  (plain, i) => ChatMessage.fromPlain(plain, id, i))

// 写：响应式 → 纯数据
const plainMessages = this.vm.historyMessage.map(
  (m, i) => m.toPlain(this.vm.sessionId, i))
```

> 💡 **为什么不能直接 `JSON.stringify(ChatMessage)`？** 因为它带 `@ObservedV2 / @Trace`，装饰器改写了属性描述符，`stringify` 会丢掉 Trace 字段。所以必须有一层"纯数据双胞胎"`ChatMessagePlain` 专门负责 IO，两者之间显式 mapper。这是 ArkTS 响应式 + 持久化的固定套路 —— 详见 25 篇。

读写两端各加一个字段就收工：

```ts
// 写库（ChatRdb.saveSession）
const mValues = { /* ...原字段... */, 'status': m.status }

// 读库（ChatRdb.loadMessages）
m.status = rs.getString(rs.getColumnIndex('status')) as MessageStatus
```

---

## 五、什么时候落库：流式结束那一下，失败/停止也算

最后一块拼图：**何时写**。AI 是一个字一个字蹦的，**绝不能每个字都写一次库**（写放大离谱）。正确时机是"这一轮彻底结束的瞬间"，也就是 `isLoading` 从 `true` 翻回 `false` 那一下。用 `@Monitor` 盯着它：

```ts
// ChatTabComp.ets
@Monitor('vm.isLoading')
onLoadingChange(): void {
  if (this.vm.isLoading) return            // 流式开始，不写
  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
  this.sessionController.persistSession(ctx) // true→false：完整会话写一次
}
```

妙在：上一篇里**成功、失败、停止**最终都会走到 `finishRequest()` 把 `isLoading` 置回 `false`。所以这一个监听**同时覆盖了三种收尾** —— 你不用在每个分支手动调保存，`STOPPED`、`FAILED` 状态自然也跟着落库了。重进历史会话，"已停止""失败可重试"原样还在。

而"重发同一个会话不会写出两份"，靠的是 `saveSession` 内部**先按 sessionId 删、再整段插**，天然幂等（这点 25 篇讲过）。

---

## 六、把整条链路连起来看

```text
            发送/重发/重新生成
                  │  状态在内存里流转：SENDING/THINKING/STREAMING…
                  ▼
        finishRequest() → isLoading: true → false
                  │
                  ▼  @Monitor('vm.isLoading')
        persistSession()
                  │  ChatMessage.toPlain()  （响应式 → 纯数据）
                  ▼
        ChatRdb.saveSession()  → status 单独一列落库
                  │
        ┄┄┄┄ App 重启 ┄┄┄┄
                  │
        ChatRdb.loadMessages()  → 读出 status 列
                  │  ChatMessage.fromPlain()  （纯数据 → 响应式 + 过程态归一化）
                  ▼
        历史会话：DONE/STOPPED/FAILED 原样还原；
                 过程态 → FAILED（可重试，不卡死）
```

---

## 七、一句话心智模型

```text
状态单独一列（要查就别塞 JSON），建表给 DEFAULT。
老库加列别指望 CREATE IF NOT EXISTS —— 它跳过已存在的表；
要 ALTER ADD COLUMN，try/catch 吞"已存在"做到幂等，DEFAULT 回填老行。
读回归一化：终态原样还原，过程态(SENDING/THINKING/STREAMING)一律改 FAILED。
转换下沉到模型 fromPlain/toPlain，Controller 只调度不手写映射。
落库时机：isLoading true→false 那一下，成功/失败/停止一网打尽。
```

## 八、顺口溜

```text
状态独立一列站，要查要排不靠 JSON 攒；
老库加列有玄机，CREATE 跳过白忙活，
ALTER 补列 try 一吞，DEFAULT 回填老行稳。
读回别认过程态，思考发送都改败（FAILED）；
转换归还给模型，from/toPlain 各就位。
落库就盯 loading 落，停失成功一锅端。
```

---

## 九、参考

- [关系型数据库 relationalStore（@kit.ArkData）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-relationalstore) —— `executeSql` / `ALTER TABLE` / `ValuesBucket`
- [RDB 数据持久化指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-rdb-store)
- [@Monitor](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-monitor) —— 监听 isLoading 触发落库
- [@ObservedV2 / @Trace](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-new-observedv2-and-trace) —— 为什么不能直接 stringify
- 本系列：[25-arkts-rdb-chat-persistence](./25-arkts-rdb-chat-persistence.md)（RDB 基础）、[27-arkts-message-status-state-machine](./27-arkts-message-status-state-machine.md)（状态机建模）、[28-arkts-resend-regenerate-idempotency](./28-arkts-resend-regenerate-idempotency.md)（编排与幂等）
