# HarmonyOS 会话抽屉实战：RDB、会话切换、左滑删除与并发保护

> 系列第 2 篇。上一篇统一了状态所有权，这一篇沿着真实代码走一遍：历史摘要怎样查询、会话怎样切换、删除为什么需要事务，以及流式生成期间为什么不能允许用户随意操作会话。

## 一、先区分“历史摘要”和“当前消息”

聊天历史通常包含两类数据：

1. **会话摘要**：ID、标题、最后一条消息预览、创建时间、更新时间；
2. **完整消息**：角色、正文、卡片、消息状态和发送时间。

抽屉一次只需要展示摘要。如果每次打开抽屉都把所有会话的全部消息加载出来，会浪费查询和对象转换成本。

当前 RDB 使用两张表：

```sql
CREATE TABLE IF NOT EXISTS chat_session (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  preview TEXT,
  create_time INTEGER NOT NULL,
  update_time INTEGER NOT NULL
)
```

```sql
CREATE TABLE IF NOT EXISTS chat_message (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT,
  create_time INTEGER NOT NULL,
  card_json TEXT,
  status TEXT NOT NULL DEFAULT 'done'
)
```

这是一种典型的“摘要先查、消息懒加载”设计：

```text
打开抽屉 → 查询 chat_session
选择会话 → 根据 session_id 查询 chat_message
```

## 二、会话模型为什么使用纯数据对象

`ChatViewModel` 中的消息是响应式的 `ChatMessage`：

```ts
@ObservedV2
export class ChatMessage {
  id: string = ''
  role: string = ''
  @Trace content: string = ''
  createTime: number = 0
  sessionId: string = ''
  @Trace card: Object | null = null
  @Trace status: MessageStatus = MessageStatus.DONE
  @Trace errorHint: string = ''
}
```

流式回复期间，`content`、`status` 和 `card` 会持续驱动 UI 更新。但响应式对象不适合直接作为数据库传输模型，因此项目又定义了 `ChatMessagePlain`：

```ts
export class ChatMessagePlain {
  id: string = ''
  role: string = ''
  content: string = ''
  createTime: number = 0
  sessionId: string = ''
  card: Object | null = null
  status: MessageStatus = MessageStatus.DONE
}
```

两者通过模型方法转换：

```ts
const uiMessage = ChatMessage.fromPlain(plain, sessionId, index)
const storedMessage = uiMessage.toPlain(sessionId, index)
```

这个边界解决了两个问题：

- 数据库层不需要理解 `@ObservedV2` 和 `@Trace`；
- 历史消息读回后重新成为响应式实例，后续重发、重新生成和状态渲染仍然有效。

## 三、打开抽屉时加载摘要

### 3.1 RDB 只查询摘要列

`ChatRdb.loadSessions()` 不加载消息正文：

```ts
static async loadSessions(): Promise<ChatSession[]> {
  if (ChatRdb.store === null) return []
  const list: ChatSession[] = []

  const pred = new relationalStore.RdbPredicates('chat_session')
  pred.orderByDesc('update_time')
  const rs = await ChatRdb.store.query(
    pred,
    ['id', 'title', 'preview', 'create_time', 'update_time']
  )

  while (rs.goToNextRow()) {
    const session = new ChatSession()
    session.id = rs.getString(rs.getColumnIndex('id'))
    session.title = rs.getString(rs.getColumnIndex('title'))
    session.preview = rs.getString(rs.getColumnIndex('preview'))
    session.createTime = rs.getLong(rs.getColumnIndex('create_time'))
    session.updateTime = rs.getLong(rs.getColumnIndex('update_time'))
    list.push(session)
  }
  rs.close()
  return list
}
```

数据库查询已经通过 `orderByDesc('update_time')` 排序。

### 3.2 Controller 再做一次排序保护

`ChatHistoryController` 对返回结果再次按更新时间倒序：

```ts
async loadData(): Promise<ChatSession[]> {
  const sessions = await ChatRdb.loadSessions()
  return sessions.sort(
    (left: ChatSession, right: ChatSession) =>
      right.updateTime - left.updateTime
  )
}
```

为什么看起来重复？因为排序是历史列表的业务约束。即使以后 `ChatRdb` 换成接口、内存假数据或其他数据源，Controller 仍能保证 UI 获得正确顺序。

### 3.3 抽屉生命周期触发加载

```ts
aboutToAppear(): void {
  this.loadData()
}

private async loadData(): Promise<void> {
  this.sessions = await this.controller.loadData()
}
```

当前 `ChatTabComp` 在关闭抽屉时会把组件从树中移除，因此每次重新打开都会重新触发 `aboutToAppear()`，自然拿到最新摘要。

抽屉还监听父层操作状态：

```ts
@Monitor('operationPending')
onOperationPendingChange(): void {
  if (this.visible && !this.operationPending) {
    this.loadData()
  }
}
```

父层持久化或加载结束后，再刷新一次列表，可以更新标题、预览和时间。

## 四、列表 UI 的几个关键细节

### 4.1 空状态和数据状态分支

```ts
if (this.sessions.length === 0) {
  Column({ space: 12 }) {
    Text('○')
    Text('暂无对话记录')
    Text('点击右上角新建会话开始聊天')
  }
} else {
  List() {
    // 会话项
  }
}
```

空状态不是异常。一个刚安装的本地 Demo 没有数据是正常业务状态，不应该显示错误提示。

### 4.2 使用稳定 ID 作为 `ForEach` Key

```ts
ForEach(
  this.sessions,
  (session: ChatSession) => {
    // ListItem
  },
  (session: ChatSession) => session.id
)
```

删除列表项时，如果使用数组下标作为 Key，后续元素的身份会整体变化，可能导致手势状态或局部 UI 复用错位。会话 ID 才是稳定身份。

### 4.3 标记当前会话

```ts
if (session.id === this.currentSessionId) {
  Text('当前')
    .fontSize(10)
    .fontColor(this.theme.primary)
}
```

背景也同步区分：

```ts
.backgroundColor(
  session.id === this.currentSessionId
    ? this.theme.infoBg
    : this.theme.surface
)
```

这不是纯装饰。它告诉用户点击列表后当前聊天区域究竟对应哪条记录。

### 4.4 时间格式化属于列表展示逻辑

```ts
formatTime(ms: number): string {
  const date = new Date(ms)
  const now = new Date()
  const isToday = date.toDateString() === now.toDateString()

  if (isToday) {
    return `${String(date.getHours()).padStart(2, '0')}:` +
      `${String(date.getMinutes()).padStart(2, '0')}`
  }
  return `${date.getMonth() + 1}/${date.getDate()}`
}
```

今天显示时分，历史日期显示月/日，信息密度比完整时间戳更适合窄抽屉。

## 五、点击历史会话：只传 ID，不传整棵对象

抽屉点击项时只上报 `sessionId`：

```ts
.onClick(() => {
  this.requestSelectSession(session.id)
})
```

```ts
private async requestSelectSession(sessionId: string): Promise<void> {
  if (this.actionsLocked()) {
    return
  }
  if (sessionId === this.currentSessionId) {
    this.requestClose()
    return
  }

  this.isOperating = true
  try {
    await this.onSelectSession(sessionId)
  } finally {
    this.isOperating = false
  }
}
```

只传 ID 有三个优势：

- 摘要对象没有完整消息，传过去也无法直接恢复会话；
- 数据源仍是 RDB，避免使用可能过期的列表快照；
- 组件事件接口更小、更稳定。

父组件收到 ID 后执行真正的切换：

```ts
private async selectHistorySession(sessionId: string): Promise<void> {
  if (this.vm.isLoading) {
    this.showGeneratingHint()
    return
  }
  if (this.sessionOperationPending) {
    this.showOperationPendingHint()
    return
  }

  this.sessionOperationPending = true
  try {
    const ctx = this.getUIContext().getHostContext()
      as common.UIAbilityContext
    const loaded = await this.sessionController
      .loadSessionById(sessionId, ctx)

    if (!loaded) {
      // Toast：会话已不存在
      return
    }
    this.closeHistoryDrawer()
  } finally {
    this.sessionOperationPending = false
  }
}
```

注意关闭抽屉发生在 `loaded === true` 之后。如果数据库加载失败，抽屉仍保持打开，用户可以选择其他会话或重试。

## 六、加载会话时怎样更新同一个 ViewModel

`ChatSessionController.loadSessionById()` 的核心实现：

```ts
async loadSessionById(
  id: string,
  ctx: common.UIAbilityContext
): Promise<boolean> {
  const sourceMessages: ChatMessagePlain[] =
    await ChatRdb.loadMessages(id)

  if (sourceMessages.length === 0) {
    LogUtil.w(
      'ChatSessionController',
      'session not found or empty: ' + id
    )
    return false
  }

  this.vm.historyMessage = sourceMessages.map(
    (plain: ChatMessagePlain, index: number) =>
      ChatMessage.fromPlain(plain, id, index)
  )
  this.vm.sessionId = id
  this.vm.inputContent = ''
  this.vm.isLoading = false
  return true
}
```

加载顺序值得注意：

1. 先等待数据库返回；
2. 空消息视为加载失败，不提前破坏当前界面；
3. 转换为响应式 `ChatMessage[]`；
4. 再更新 `sessionId`、草稿和运行时状态。

这比“点击后先清空当前消息，再异步查询”更稳妥。后者在查询失败时会让用户丢失正在看的内容。

## 七、新建会话必须是一个原子语义

`ChatViewModel` 提供统一重置方法：

```ts
resetForNewSession(): void {
  this.sessionId = Date.now().toString()
  this.historyMessage = []
  this.inputContent = ''
  this.isLoading = false
}
```

Controller 先检查生成状态：

```ts
newSession(): boolean {
  if (this.vm.isLoading) {
    return false
  }
  this.vm.resetForNewSession()
  return true
}
```

返回 `boolean`，让调用方决定怎样提示用户：

```ts
private requestNewSession(): void {
  if (this.sessionOperationPending) {
    this.showOperationPendingHint()
    return
  }
  if (!this.sessionController.newSession()) {
    this.showGeneratingHint()
    return
  }
  this.closeHistoryDrawer()
}
```

不要在多个点击事件里分别清空消息、草稿和 ID。只要漏掉一个字段，新旧会话就可能串在一起。

## 八、删除会话：UI 即时更新与数据库事务

### 8.1 左滑操作

ArkUI 的 `ListItem` 可以直接配置结束方向操作：

```ts
ListItem() {
  // 会话内容
}
.swipeAction({ end: this.deleteButton(session.id) })
```

删除按钮使用 `@Builder`：

```ts
@Builder
deleteButton(sessionId: string) {
  Button('删除')
    .width(72)
    .height('100%')
    .onClick(() => {
      this.requestDeleteSession(sessionId)
    })
}
```

### 8.2 删除成功后本地过滤

```ts
async deleteSession(
  sessionId: string,
  sessions: ChatSession[]
): Promise<ChatSession[] | null> {
  const deleted = await ChatRdb.deleteSession(sessionId)
  if (!deleted) {
    return null
  }
  return sessions.filter(
    (session: ChatSession) => session.id !== sessionId
  )
}
```

成功后直接生成新数组，抽屉立即刷新；失败返回 `null`，调用方保留原列表并显示 Toast。

这里不能在数据库结果未知时先从 UI 删除。否则数据库失败后还需要把列表项补回去，容易产生闪烁和状态错位。

### 8.3 为什么删除必须使用事务

一个会话横跨两张表：

```text
chat_session：1 行摘要
chat_message：N 行消息
```

如果先删摘要成功、再删消息失败，会留下孤立消息。反过来也会留下无法打开的空摘要。

当前实现把两次删除放进事务：

```ts
static async deleteSession(sessionId: string): Promise<boolean> {
  if (ChatRdb.store === null) return false
  let transaction: relationalStore.Transaction | null = null

  try {
    transaction = await ChatRdb.store.createTransaction()

    const sessionPred =
      new relationalStore.RdbPredicates('chat_session')
    sessionPred.equalTo('id', sessionId)
    await transaction.delete(sessionPred)

    const messagePred =
      new relationalStore.RdbPredicates('chat_message')
    messagePred.equalTo('session_id', sessionId)
    await transaction.delete(messagePred)

    await transaction.commit()
    return true
  } catch (error) {
    if (transaction !== null) {
      try {
        await transaction.rollback()
      } catch (rollbackError) {
        LogUtil.e(
          'ChatRdb',
          'deleteSession rollback failed: ' +
            JSON.stringify(rollbackError)
        )
      }
    }
    LogUtil.e(
      'ChatRdb',
      'deleteSession failed: ' + JSON.stringify(error)
    )
    return false
  }
}
```

事务的语义是：两张表一起成功，或者一起回滚。

### 8.4 删除当前会话

抽屉删除完成后，把 ID 上报给父组件：

```ts
this.sessions = updatedSessions
this.onSessionDeleted(sessionId)
```

父组件判断它是否是当前会话：

```ts
private onHistorySessionDeleted(sessionId: string): void {
  if (sessionId === this.vm.sessionId) {
    this.sessionController.newSession()
  }
}
```

如果不重置，聊天区域仍会显示已经从数据库删除的消息。用户下一次发送内容时，这个“幽灵会话”甚至可能被重新保存。

## 九、最难处理的点：会话操作与流式生成并发

假设 AI 正在流式输出，用户此时切换到另一个会话：

```text
旧请求仍在追加 chunk
        ↓
historyMessage 已替换为新会话
        ↓
旧请求可能把内容写到错误的 UI 或错误 sessionId
```

所以“按钮可点击”不是纯视觉问题，而是状态一致性问题。

### 9.1 第一层锁：生成状态

抽屉统一检查：

```ts
private actionsLocked(): boolean {
  if (this.isGenerating) {
    this.showHint('AI 正在生成回复，请先停止或等待完成')
    return true
  }
  if (this.operationPending || this.isOperating) {
    this.showHint('正在处理会话，请稍候')
    return true
  }
  return false
}
```

生成期间禁止：

- 切换会话；
- 删除会话；
- 新建会话。

关闭抽屉可以根据产品策略决定是否允许；当前实现只在会话操作进行中禁止关闭，生成期间仍可收起抽屉。

### 9.2 第二层锁：父组件异步操作

`sessionOperationPending` 表示加载或持久化尚未完成：

```ts
this.sessionOperationPending = true
try {
  await this.sessionController.persistSession(ctx)
} finally {
  this.sessionOperationPending = false
}
```

这层锁由 `ChatTabComp` 持有，因为它保护的是当前会话状态。

### 9.3 第三层锁：抽屉内部重复操作

`isOperating` 防止用户连续点击两个列表项或重复删除：

```ts
this.isOperating = true
try {
  await this.onSelectSession(sessionId)
} finally {
  this.isOperating = false
}
```

父层锁和子层锁看似相似，保护范围不同：

| 状态 | 所有者 | 保护对象 |
| --- | --- | --- |
| `vm.isLoading` | `ChatViewModel` | 流式请求生命周期 |
| `sessionOperationPending` | `ChatTabComp` | 当前会话加载/保存 |
| `isOperating` | `ChatHistoryDrawerComp` | 抽屉内重复点击 |

把所有锁合成一个全局布尔值，会让不同操作互相污染；分层后更容易理解谁负责释放。

## 十、流式结束后再持久化

`ChatTabComp` 监听 `vm.isLoading`：

```ts
@Monitor('vm.isLoading')
onLoadingChange(): void {
  if (this.vm.isLoading) {
    return
  }
  this.persistCurrentSession()
}
```

```ts
private async persistCurrentSession(): Promise<void> {
  this.sessionOperationPending = true
  try {
    const ctx = this.getUIContext().getHostContext()
      as common.UIAbilityContext
    await this.sessionController.persistSession(ctx)
  } finally {
    this.sessionOperationPending = false
  }
}
```

Controller 根据消息生成摘要：

- 标题取第一条用户消息前 20 个字符；
- 预览取最后一条消息前 30 个字符；
- 创建时间取第一条消息；
- 更新时间取最后一条消息。

这样抽屉无需扫描完整消息表就能展示列表。

## 十一、测试应该覆盖状态契约

目前针对新建会话有两个 Hypium 测试。

### 11.1 空闲时正确重置

```ts
const changed = controller.newSession()

expect(changed).assertTrue()
expect(vm.sessionId === 'session-old').assertFalse()
expect(vm.inputContent).assertEqual('')
expect(vm.historyMessage.length).assertEqual(0)
```

### 11.2 生成期间拒绝修改

```ts
vm.isLoading = true
const changed = controller.newSession()

expect(changed).assertFalse()
expect(vm.sessionId).assertEqual('session-active')
expect(vm.inputContent).assertEqual('draft')
expect(vm.historyMessage.length).assertEqual(1)
expect(vm.isLoading).assertTrue()
```

第二个测试尤其重要：它验证的不只是返回值，而是失败时不能产生任何部分修改。

## 十二、可以继续完善的地方

当前实现已经满足本地 Demo，但产品化时可以继续演进：

1. `sessionId` 可替换为 UUID，避免极端情况下同一毫秒创建冲突；
2. `saveSession()` 也可以使用事务，保证摘要和消息整体覆盖；
3. 空会话可以单独保存元数据，让刚新建但未发送消息的会话也出现在历史中；
4. 历史列表增加分页、搜索和置顶时，仍应保持“摘要查询”和“消息加载”分离；
5. 流式请求可以绑定不可变的请求级 `sessionId`，再增加一层结果归属校验。

这些增强都不需要改变当前组件边界，说明现有结构具备继续扩展的空间。

## 十三、小结

会话抽屉真正困难的部分不是 `ListItem.swipeAction`，而是确保每个异步动作都不会破坏当前聊天状态。

可以把本文总结成四条规则：

1. 摘要与完整消息分开查询；
2. 抽屉只上报 ID，当前状态由父组件更新；
3. 删除跨表数据必须考虑事务；
4. 流式生成和会话加载都要有明确的临界区。

下一篇将复盘这次重构中最隐蔽的故障：抽屉已经透明且滑出屏幕，为什么输入框仍然完全点不进去？

上一篇：[单入口右侧抽屉架构](./34-harmony-chat-single-entry-drawer-architecture.md)  
下一篇：[隐形遮罩为何挡住 TextInput](./36-arkui-invisible-overlay-blocks-textinput.md)
