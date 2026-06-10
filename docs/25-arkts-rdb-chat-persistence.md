# 聊天历史从 Preferences 搬到关系型数据库（RDB）：为什么换、怎么换、踩了什么坑

> 项目：`MyApplication`（AI 助手 demo）
> 目标文件：`chat/src/main/ets/utils/ChatRdb.ets`（新建） + `controller/ChatSessionController.ets` + `controller/ChatHistoryController.ets` + `EntryAbility.ets`
> 主题：早期 demo 用 **Preferences + JSON.stringify(整个 sessions 列表)** 存聊天记录，会话数一上来就开始卡。今天把它换成 **关系型数据库（@kit.ArkData / relationalStore）**，建两张表 `chat_session` / `chat_message` + 一个索引。本篇把 ArkTS 里用 RDB 的最小闭环 + 这次替换的设计决策记下来。

---

## 一、为什么 Preferences 顶不住了

旧实现（`ChatPersist.ets`）：

```ts
const STORE_NAME = 'chat_history'
const KEY_SESSIONS = 'sessions'

export function saveSession(ctx, session: ChatSession): void {
  const store = preferences.getPreferencesSync(ctx, { name: STORE_NAME })
  const raw = store.getSync(KEY_SESSIONS, '[]') as string
  const list = JSON.parse(raw) as ChatSession[]            // 1. 把全部会话读出来
  const idx = list.findIndex(s => s.id === session.id)
  if (idx >= 0) list[idx] = session                         // 2. 在内存里改
  else list.push(session)
  store.putSync(KEY_SESSIONS, JSON.stringify(list))         // 3. 整个列表 stringify 写回
  store.flush()
}
```

这是经典的 **KV 持久化（Key-Value）** 套路：一个 key 装下所有数据。问题：

| 维度 | Preferences 版 | 现实情况 |
|---|---|---|
| **写一次的成本** | 序列化整个 sessions 列表 → 写整张 KV | 100 个会话 × 平均 30 条消息 ≈ 几百 KB JSON 每次都要全量重写 |
| **读单条** | 必须先 `JSON.parse` 全部 → 找到 id 那条 | 想看一个会话，要把无关的 99 个也解析出来 |
| **查询** | 没有 query，只能加载全量后在内存 filter / sort | 历史页要"按 updateTime 倒序" → 全表读 + sort |
| **崩溃恢复** | 如果中途 stringify 出错，要么全成功要么全失败 | 一条脏数据可能让全部历史读不出来 |
| **并发** | flush 是异步的，多次 put 间隔写可能错位 | 流式生成边写边来，时序难保证 |

KV 是 **整存整取**，对会话这种"按 id 检索 + 排序 + 增量更新"的数据完全不合身。

**RDB（SQLite 封装）才是聊天记录这种数据应该用的存储**：

| 维度 | RDB |
|---|---|
| **写一次** | 单条 insert / update / delete |
| **读单条** | `WHERE id = ?` 索引命中，毫秒级 |
| **查询** | SQL / RdbPredicates 支持 where / order / limit / join |
| **崩溃恢复** | 事务、WAL，原子性有保障 |
| **并发** | RDB 自带行锁 / 文件锁 |

---

## 二、ArkTS 里用 RDB 的最小五步

来自 `@kit.ArkData` 的 `relationalStore` 模块。最小闭环：

### 2.1 `getRdbStore` 拿 store

```ts
import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'

const config: relationalStore.StoreConfig = {
  name: 'chat.db',
  securityLevel: relationalStore.SecurityLevel.S1
}
const store = await relationalStore.getRdbStore(ctx, config)
```

- `name` —— SQLite 文件名，每个 App 私有目录下一个
- `securityLevel` —— 数据敏感等级，决定加密 / 访问控制策略。S1 是最低，适合本地缓存类数据。如果存账户 token / 用户隐私走 S3+

```text
SecurityLevel.S1  低敏感（demo 数据、本地缓存）
SecurityLevel.S2  低敏感但有一定隐私（昵称、头像 URL）
SecurityLevel.S3  中敏感（手机号、地理位置）
SecurityLevel.S4  高敏感（身份证、银行卡）
```

> 一旦选定，**升级 securityLevel 是兼容的，降级是不兼容的**。第一次选高一点不会错。

### 2.2 `executeSql` 建表 + 建索引

```ts
const SQL_CREATE_SESSION = `
  CREATE TABLE IF NOT EXISTS chat_session (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    preview TEXT,
    create_time INTEGER NOT NULL,
    update_time INTEGER NOT NULL
  )
`
const SQL_CREATE_MESSAGE = `
  CREATE TABLE IF NOT EXISTS chat_message (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT,
    create_time INTEGER NOT NULL,
    card_json TEXT
  )
`
const SQL_CREATE_INDEX = `
  CREATE INDEX IF NOT EXISTS idx_msg_session
  ON chat_message(session_id, create_time)
`

await store.executeSql(SQL_CREATE_SESSION)
await store.executeSql(SQL_CREATE_MESSAGE)
await store.executeSql(SQL_CREATE_INDEX)
```

`IF NOT EXISTS` 让这段在每次 init 时都能安全跑 —— 已存在就跳过。

### 2.3 `RdbPredicates` + `query` 读

```ts
const pred = new relationalStore.RdbPredicates('chat_session')
pred.orderByDesc('update_time')                            // ORDER BY update_time DESC

const rs = await store.query(pred, ['id', 'title', 'preview', 'create_time', 'update_time'])
while (rs.goToNextRow()) {
  const s = new ChatSession()
  s.id    = rs.getString(rs.getColumnIndex('id'))
  s.title = rs.getString(rs.getColumnIndex('title'))
  // ...
}
rs.close()                                                  // 必须 close，否则游标泄漏
```

`RdbPredicates` 是用链式 API 拼 `WHERE / ORDER / LIMIT` 子句的对象，可读性比手拼 SQL 字符串高，也避免注入。

### 2.4 `ValuesBucket` + `insert` 写

```ts
const sValues: relationalStore.ValuesBucket = {
  'id': session.id,
  'title': session.title,
  'preview': session.preview,
  'create_time': session.createTime,
  'update_time': session.updateTime
}
await store.insert('chat_session', sValues)
```

`ValuesBucket` 就是 `{ 列名: 值 }` 的字典，按列名插值。注意 ArkTS 里 key 必须是字符串字面量（有引号），这是 strict type 的要求。

### 2.5 `delete` 删

```ts
const pred = new relationalStore.RdbPredicates('chat_session')
pred.equalTo('id', sessionId)
await store.delete(pred)
```

`equalTo / notEqualTo / greaterThan / lessThan / between / like / in` 全套都有，跟 SQL WHERE 一一对应。

---

## 三、这次的表设计

### 3.1 拆成 session + message 两张表

旧的 Preferences 把 `ChatSession.messages: ChatMessage[]` 整段塞 JSON 里。RDB 设计的核心是 **把"一对多关系拆开成两张表 + 外键列"**：

```text
chat_session (元数据，一行一会话)
  ├─ id            会话主键，时间戳字符串
  ├─ title         会话标题（第一条 user 消息前 20 字）
  ├─ preview       预览（最后一条消息前 30 字）
  ├─ create_time
  └─ update_time

chat_message (内容，一行一消息)
  ├─ id            消息主键
  ├─ session_id    ← 外键指向 chat_session.id
  ├─ role          'user' | 'assistant'
  ├─ content       文本内容
  ├─ create_time
  └─ card_json     卡片对象 JSON.stringify（PickupCard）

idx_msg_session (chat_message 的复合索引)
  ON chat_message(session_id, create_time)
```

### 3.2 为什么加 `idx_msg_session`

聊天最常见的查询是 **"按 session_id 拉某个会话的所有消息，按时间正序"**：

```sql
SELECT * FROM chat_message
WHERE session_id = ?
ORDER BY create_time ASC
```

如果没有索引，会全表扫 + 排序；加上 `(session_id, create_time)` 这个复合索引：

- `session_id` 等值过滤直接命中索引
- `create_time` 在索引上已经排好序，**不需要额外的 sort 操作**

代价：每条 insert 多写一次索引（很小）。**对读多写少的场景，索引是必加的**。

### 3.3 卡片字段：`card_json` 用 JSON 兜底

`ChatMessagePlain.card` 是个 `PickupCard | null`，PickupCard 里面套着 `PickupPoint[]` 等嵌套结构。**不想为这一个字段再拆出第三张表**，干脆：

```ts
card_json: m.card !== null ? JSON.stringify(m.card) : ''
```

读出来时反序列化：

```ts
const cardJson = rs.getString(rs.getColumnIndex('card_json'))
m.card = cardJson.length > 0 ? (JSON.parse(cardJson) as Object) : null
```

**判断"是否有卡片"用 `length > 0` 而不是 `!== null`** —— RDB 的 TEXT 列空值取出来是空串而不是 null，写代码时要适配。

---

## 四、最关键的转换：`ChatMessage` ↔ `ChatMessagePlain`

ArkUI 响应式带来一个隐藏麻烦：**`@ObservedV2 / @Trace` 装饰的对象，JSON.stringify 拿不到完整字段**。装饰器会改写属性描述符（getter/setter + 内部存值），`stringify` 走的是默认 enumerable 字段路径，**Trace 字段会丢**。

解决方案：**存储用普通对象，UI 用 ObservedV2 对象，两者之间做转换**。

```ts
// UI 用：ChatMessage（@ObservedV2 / @Trace 装饰，驱动气泡实时更新）
@ObservedV2
export class ChatMessage {
  @Trace content: string = ''
  @Trace role: string = ''
  // ...
}

// 存储用：ChatMessagePlain（普通 class，字段裸露）
export class ChatMessagePlain {
  content: string = ''
  role: string = ''
  // ...
}
```

写入时 `ChatMessage → ChatMessagePlain`：

```ts
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

读出来时 `ChatMessagePlain → ChatMessage`：

```ts
private convertToObservable(plains: ChatMessagePlain[], sessionId: string): ChatMessage[] {
  return plains.map((plain, i) => {
    const msg = new ChatMessage()
    msg.id = plain.id ? plain.id : `${sessionId}_${i}`
    msg.role = plain.role ? plain.role : 'assistant'
    msg.content = plain.content ? plain.content : ''
    // ...
    return msg
  })
}
```

每个字段都加 `? : fallback` —— **不信任老数据**。这一层是为了过去版本写下的脏数据 / 字段缺失的情况能正常加载。

> 这是 ArkTS 响应式 + 持久化的标准模式：**Observable 类负责 UI 响应，Plain 类负责 IO 序列化，两者之间显式 mapper**。不要试图给 ObservedV2 类直接 stringify。

---

## 五、初始化时机：EntryAbility.onCreate 调一次

数据库要在 App 一启动就准备好，不能等到第一次 saveSession 才 init —— 那时候已经晚了（可能正在生成回复，等不起 init 的 await）。

```ts
// entry/src/main/ets/entryability/EntryAbility.ets
import { ChatRdb } from 'chat'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HMRouterMgr.init({ context: this.context })

    // 数据库初始化（一次）
    ChatRdb.init(this.context)

    HMRouterMgr.registerGlobalInterceptor({ ... })
    // ...
  }
}
```

`ChatRdb.init` 内部用静态 store 字段 + 短路：

```ts
private static store: relationalStore.RdbStore | null = null

static async init(ctx: common.UIAbilityContext): Promise<void> {
  if (ChatRdb.store !== null) return                  // 已 init 过直接返回

  const config: relationalStore.StoreConfig = { name: 'chat.db', securityLevel: relationalStore.SecurityLevel.S1 }
  try {
    ChatRdb.store = await relationalStore.getRdbStore(ctx, config)
    await ChatRdb.store.executeSql(SQL_CREATE_SESSION)
    await ChatRdb.store.executeSql(SQL_CREATE_MESSAGE)
    await ChatRdb.store.executeSql(SQL_CREATE_INDEX)
    LogUtil.i('ChatRdb', 'init success')
  } catch (e) {
    LogUtil.e('ChatRdb', 'init failed: ' + JSON.stringify(e))
  }
}
```

后续所有方法都 **守一道空检查 + 静默返回**：

```ts
static async loadSessions(): Promise<ChatSession[]> {
  if (ChatRdb.store === null) return []          // ← init 还没跑完直接返回空
  // ...
}
```

**为什么不抛错而是返回空**：聊天页加载历史失败时，给用户看 `[]`（"暂无会话"）比给个红屏好。崩了反而让用户怀疑 App 坏了，错日志去 LogUtil.e 留着开发自查。

---

## 六、跨模块导出：把 ChatRdb 挂在 chat HAR 的对外 API 上

`chat/Index.ets`：

```ts
// === Chat HAR 对外公开 API ===

// 唯一对外暴露的 UI 组件：让 entry 的 HomePage 嵌入 Chat Tab
export { ChatTabComp } from './src/main/ets/components/ChatTabComp'

// 路由常量
export { ChatRoutes } from './src/main/ets/constants/ChatRoutes'

// 跨页面通信
export { ChatLoadState, getChatLoadState } from './src/main/ets/viewmodel/ChatLoadState'

// 关系型数据库，聊天记录存入数据库中，调用这个方法
export { ChatRdb } from './src/main/ets/utils/ChatRdb'
```

entry 模块只需要 import 一个 `ChatRdb` 就能在 EntryAbility 里调 init。**别让 entry 直接 import chat 模块的内部路径** —— 那样就破坏 HAR 边界了。

---

## 七、保存时机：流式结束才写一次

聊天 UI 里 AI 是边生成边追加 token 的，**不能每个 token 都写库**（写放大很离谱）。`ChatTabComp` 里用 `@Monitor` 监听 `isLoading` 的变化：

```ts
@Monitor('vm.isLoading')
onLoadingChange(): void {
  if (this.vm.isLoading) {
    return                                       // 流式开始，不写
  }
  // 流式结束（isLoading: true → false），把完整会话写一次
  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
  this.sessionController.persistSession(ctx)
}
```

`persistSession` 内部走"先 delete 再 insert"的最简实现：

```ts
// 1. 删 session 行
const sPred = new relationalStore.RdbPredicates('chat_session')
sPred.equalTo('id', session.id)
await ChatRdb.store.delete(sPred)

// 2. 插 session 行
await ChatRdb.store.insert('chat_session', sValues)

// 3. 删该 sessionId 下的所有 message
const mPred = new relationalStore.RdbPredicates('chat_message')
mPred.equalTo('session_id', session.id)
await ChatRdb.store.delete(mPred)

// 4. 批量插 message
for (let i = 0; i < session.messages.length; i++) {
  await ChatRdb.store.insert('chat_message', mValues)
}
```

**没有用事务 / batchInsert 是有意为之** —— demo 阶段每次保存就是 1 个 session + 几十条 message 量级，单条 insert 跑得动。等会话规模再上一个量级（>500 条 msg / session）再换 `batchInsert`。**不要为了"看起来更专业"提前优化**。

---

## 八、数据流：四个角色协作

```text
┌────────────────────┐
│ EntryAbility       │   onCreate 调 ChatRdb.init
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐   query / orderByDesc / delete / insert
│ ChatRdb            │ ───────────────────────────────────────┐
│ (chat/utils)       │                                        │
└─────────┬──────────┘                                        │
          │                                                    │
   ┌──────┴───────┐                                            │
   │              │                                            │
   ▼              ▼                                            ▼
┌──────────────────────┐                          ┌──────────────────────┐
│ ChatHistoryController│ 历史页 load / delete     │  chat.db (SQLite)    │
│                      │                          │  chat_session        │
└──────────────────────┘                          │  chat_message        │
┌──────────────────────┐ 流式结束 saveSession      │  idx_msg_session     │
│ ChatSessionController│ ─────────────────────────│                      │
│                      │ ChatMessage↔Plain 双向   └──────────────────────┘
└──────────────────────┘
```

- `EntryAbility.onCreate` —— 全局 init 一次
- `ChatRdb` —— 唯一的 RDB 入口，所有 SQL / Predicates 在这里
- `ChatSessionController` —— 流式结束触发 saveSession + 双向转换 ObservedV2 ↔ Plain
- `ChatHistoryController` —— 历史页加载列表 + 删除单条

业务层 **完全不感知 SQL / RdbPredicates** —— 它们只调 `ChatRdb.loadMessages(id)` 这种语义化方法。

---

## 九、几个意外发现

### 9.1 RdbPredicates 上的 column name 是 SQL 列名，不是 ArkTS 属性名

```ts
// ✅ SQL 列名（下划线风格）
pred.orderByDesc('update_time')

// ❌ 不是 ArkTS 属性名（camelCase）
pred.orderByDesc('updateTime')        // 查不到
```

`ChatSession.updateTime` 是 ArkTS 属性，`chat_session.update_time` 是数据库列名。RdbPredicates 操作的是数据库，**永远用列名**。这是 ORM 缺位下手写映射要小心的地方。

### 9.2 resultSet 必须 `close`

```ts
const rs = await store.query(pred)
while (rs.goToNextRow()) { ... }
rs.close()                              // ← 不写这一行会泄漏文件句柄
```

ArkTS 没有 RAII / using，资源释放靠程序员自觉。漏 close 单看不出问题，但在循环里反复查询会很快耗尽句柄。

### 9.3 PRIMARY KEY 冲突时 insert 是抛异常的

我一开始想"既然 id 是主键，insert 同 id 时应该会失败 / 覆盖"，结果是 **抛异常**。所以这次 saveSession 走的是 **"先 delete 再 insert"** 而不是 "INSERT OR REPLACE"（后者需要拼原始 SQL）。

更优雅的写法是 `INSERT OR REPLACE INTO ... ON CONFLICT`，但 demo 阶段两步走读起来清楚。

---

## 十、一句话心智模型

```text
KV 是「整存整取」，RDB 是「按列检索 + 增量更新」。
聊天记录这种"按 id 拉 + 按时间排"的数据，必须用 RDB。

五步走：getRdbStore → executeSql 建表 → Predicates 查 → ValuesBucket 写 → delete 删。

ObservedV2 不能直接 stringify，加一层 Plain 做 IO 双向 mapper。
Init 在 EntryAbility.onCreate 调一次，业务层只走语义化接口，不碰 SQL。
```

---

## 十一、顺口溜

```text
KV 整存整取慢，每改全表写一遍；
RDB 列检索、查询快，索引加上飞起来。

ObservedV2 别 stringify，Trace 字段会消失；
Plain 类做 IO 映，双向 mapper 保字段。

init 放在 onCreate，store 静态短路开；
resultSet 用完要 close，否则句柄泄不开。
```

---

## 十二、参考

- [relationalStore API（@kit.ArkData）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-relationalstore)
- [RDB 数据持久化指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-rdb-store)
- [Preferences API（@kit.ArkData）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-preferences)（旧实现对照）
- 本系列相关：[04-chat-local-storage](./04-chat-local-storage.md) / [08-chat-history-persistence-bugfix](./08-chat-history-persistence-bugfix.md) / [23-arkts-hilog-logutil-replace-console](./23-arkts-hilog-logutil-replace-console.md)
