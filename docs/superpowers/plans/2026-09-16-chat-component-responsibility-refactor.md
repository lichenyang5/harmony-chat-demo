# 聊天组件职责拆分实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持现有聊天 UI、交互、持久化格式和公共调用方式不变的前提下，拆分流式状态机、会话保存队列、历史会话列表项和抽屉空状态。

**Architecture:** `ChatController` 保留为消息操作门面，将单次 SSE 请求的运行时状态委托给 `ChatStreamStateMachine`。`ChatTabComp` 继续持有页面响应式状态，通过 `ChatSessionSaveQueue` 串行执行保存任务；`ChatHistoryDrawerComp` 只负责编排列表数据和事件，具体行与空状态由子组件渲染。

**Tech Stack:** HarmonyOS Stage Model、ArkTS、ArkUI 状态管理 V2、NetworkKit SSE、Promise、HMRouter、ArkData RDB。

**Spec:** `docs/superpowers/specs/2026-09-16-chat-component-responsibility-refactor-design.md`

## Global Constraints

- 纯重构：不改变现有 UI、动画、Toast 文案、交互语义、RDB 结构、路由或服务端协议。
- `ChatController` 的 `sendMessage`、`resendMessage`、`regenerate`、`stopGeneration` 方法保持可用。
- 不修改 `common/src/main/ets/debug/NetMonitorPanel.ets`。
- 不使用 `any`，不留下空 `catch`、空错误分支或占位代码。
- 新增注释解释职责、状态所有权、幂等和并发原因，不逐行复述普通 UI 代码。
- 根据用户要求，本计划不新增自动化测试文件；每个任务使用静态检查与 ArkTS 编译作为实现反馈，最终真机功能验证由用户完成。

---

### Task 1: 抽取流式请求状态机

**Files:**
- Create: `chat/src/main/ets/controller/ChatStreamStateMachine.ets`
- Modify: `chat/src/main/ets/controller/ChatController.ets`

**Interfaces:**
- Consumes: `ChatViewModel`、`ChatBiz`、`ChatMessage`、`ChatHistoryItem`、`ChatError`、`MessageStatus`、`SseDoneMeta`。
- Produces: `ChatStreamStateMachine.start(userMsg, aiMsg, history, allowUserResend)` 与 `ChatStreamStateMachine.stop()`。
- Preserves: `ChatController` 的四个公共操作方法及其参数。

- [ ] **Step 1: 记录迁移前公共 API 与状态字段**

确认 `ChatController` 只有以下公共行为供组件调用：

```ts
sendMessage(): void
resendMessage(target: ChatMessage): void
regenerate(target: ChatMessage): void
stopGeneration(): void
```

运行：

```powershell
rg -n "controller\.(sendMessage|resendMessage|regenerate|stopGeneration)" chat/src/main/ets
```

预期：调用方只依赖上述四个方法，不直接读取当前 HTTP 请求或活动消息。

- [ ] **Step 2: 创建 ChatStreamStateMachine**

新类结构：

```ts
export class ChatStreamStateMachine {
  private biz: ChatBiz = new ChatBiz()
  private vm: ChatViewModel
  private currentRequest: http.HttpRequest | null = null
  private activeAiMessage: ChatMessage | null = null
  private activeUserMessage: ChatMessage | null = null
  private requestSeq: number = 0
  private finalized: boolean = true
  private allowUserResend: boolean = true

  constructor(vm: ChatViewModel) {
    this.vm = vm
  }

  start(
    userMsg: ChatMessage,
    aiMsg: ChatMessage,
    history: ChatHistoryItem[],
    allowUserResend: boolean
  ): void

  stop(): void
}
```

迁移以下行为，逻辑顺序与现有实现保持一致：

- `runStream`
- `finalizeSuccess`
- `finalizeFailure`
- `finishRequest`
- `isStale`
- 失败时移除空 AI 占位
- `stopGeneration` 中的请求销毁和消息状态处理

文件顶部注释必须说明：该类拥有单个在途请求的全部运行时状态，不创建用户操作，也不决定重发/重新生成目标。

- [ ] **Step 3: 将 ChatController 改为门面**

保留：

- `vm`
- `idSeed`
- `createMessage`
- `buildHistorySnapshot`
- 发送、重发、重新生成前的校验和消息准备

新增：

```ts
private streamStateMachine: ChatStreamStateMachine

constructor(vm: ChatViewModel) {
  this.vm = vm
  this.streamStateMachine = new ChatStreamStateMachine(vm)
}
```

将三处流式启动替换为：

```ts
this.streamStateMachine.start(userMessage, aiMessage, history, true)
```

或重新生成场景的：

```ts
this.streamStateMachine.start(promptMsg, target, history, false)
```

停止入口只委托：

```ts
stopGeneration(): void {
  this.streamStateMachine.stop()
}
```

删除已经迁移的 NetworkKit、`ChatBiz`、`ChatError`、`SseDoneMeta` import 和运行时字段。

- [ ] **Step 4: 静态检查抽取边界**

运行：

```powershell
rg -n "currentRequest|activeAiMessage|activeUserMessage|requestSeq|finalized|allowUserResend" chat/src/main/ets/controller
```

预期：这些字段只在 `ChatStreamStateMachine.ets` 中定义和修改。

运行：

```powershell
rg -n "sendMessage\(|resendMessage\(|regenerate\(|stopGeneration\(" chat/src/main/ets/controller/ChatController.ets
```

预期：四个公共入口仍存在。

- [ ] **Step 5: 编译 chat 相关 ArkTS**

使用项目的 Hvigor 环境执行 `entry` debug HAP 编译。预期 `CompileArkTS` 通过；若出现名义类型、可空类型或回调签名错误，只调整类型声明，不改变状态转换语义。

- [ ] **Step 6: 提交本任务**

```bash
git add chat/src/main/ets/controller/ChatController.ets \
  chat/src/main/ets/controller/ChatStreamStateMachine.ets
git commit -m "refactor: extract chat stream state machine"
```

---

### Task 2: 抽取会话保存队列

**Files:**
- Create: `chat/src/main/ets/controller/ChatSessionSaveQueue.ts`
- Modify: `chat/src/main/ets/components/ChatTabComp.ets`

**Interfaces:**
- Consumes: `() => Promise<void>` 保存任务和 `(pending: boolean) => void` 忙闲回调。
- Produces: `ChatSessionSaveQueue.enqueue(task, onPendingChange): Promise<void>`。
- Preserves: `ChatSessionController.persistSession(ctx)` 的签名和数据库行为。

- [ ] **Step 1: 创建保存队列**

实现目标接口：

```ts
export type ChatSessionSaveTask = () => Promise<void>
export type ChatSessionSaveStateListener = (pending: boolean) => void

export class ChatSessionSaveQueue {
  private tail: Promise<void> = Promise.resolve()
  private pendingCount: number = 0

  enqueue(
    task: ChatSessionSaveTask,
    onPendingChange: ChatSessionSaveStateListener
  ): Promise<void>
}
```

入队规则：

1. `pendingCount` 从 0 变 1 时通知 `true`。
2. 当前任务通过已恢复为 fulfilled 的 `tail.then(...)` 串行启动。
3. 返回给调用者的 Promise 保留当前任务的成功或失败结果。
4. 内部 `tail` 必须吞掉前一个任务的 rejection，并用 `LogUtil` 记录，保证下一个任务仍会执行。
5. 每个任务结束时递减计数；计数回到 0 时通知 `false`。

注释必须解释“返回值保留错误、内部尾链恢复错误”为什么是两个不同目的。

- [ ] **Step 2: ChatTabComp 接入队列**

新增字段：

```ts
private saveQueue: ChatSessionSaveQueue = new ChatSessionSaveQueue()
```

保留 `@Monitor('vm.isLoading')`，但将保存方法改为委托：

```ts
private async persistCurrentSession(): Promise<void> {
  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
  try {
    await this.saveQueue.enqueue(
      () => this.sessionController.persistSession(ctx),
      (pending: boolean) => {
        this.sessionOperationPending = pending
      }
    )
  } catch (error) {
    LogUtil.e('ChatTabComp', 'persist session failed: ' + JSON.stringify(error))
  }
}
```

不要让队列直接依赖 `ChatViewModel`、`ChatSessionController` 或 `UIAbilityContext`。

- [ ] **Step 3: 检查状态所有权**

运行：

```powershell
rg -n "sessionOperationPending|pendingCount|tail" chat/src/main/ets/components/ChatTabComp.ets chat/src/main/ets/controller/ChatSessionSaveQueue.ts
```

预期：

- 响应式 `sessionOperationPending` 只由页面持有。
- 队列只持有 `pendingCount` 与 Promise `tail`。
- 保存队列不访问抽屉可见性或消息列表。

- [ ] **Step 4: 编译验证**

执行 Hvigor debug HAP 编译，确认 ArkTS 接受 Promise 链、函数类型和 `finally`/`then` 返回类型。

- [ ] **Step 5: 提交本任务**

```bash
git add chat/src/main/ets/controller/ChatSessionSaveQueue.ts \
  chat/src/main/ets/components/ChatTabComp.ets
git commit -m "refactor: serialize chat session saves"
```

---

### Task 3: 拆分历史会话列表项与空状态

**Files:**
- Create: `chat/src/main/ets/components/ChatHistoryListItemComp.ets`
- Create: `chat/src/main/ets/components/ChatHistoryStatusComp.ets`
- Modify: `chat/src/main/ets/components/ChatHistoryDrawerComp.ets`

**Interfaces:**
- Consumes: `ChatSession`、当前会话 ID、格式化时间、操作锁状态。
- Produces: `onSelect(sessionId)` 与 `onDelete(sessionId)` 用户意图事件。
- Preserves: 原列表视觉、当前标记、点击选择和左滑删除行为。

- [ ] **Step 1: 创建 ChatHistoryStatusComp**

组件只渲染现有空状态：

```ts
@ComponentV2
export struct ChatHistoryStatusComp {
  @Local theme: ThemeState = getThemeState()

  build() {
    // 保持现有 ○、暂无对话记录、点击右上角新建会话开始聊天。
  }
}
```

不得改变原有字体、颜色、间距和背景。

- [ ] **Step 2: 创建 ChatHistoryListItemComp**

接口：

```ts
@ComponentV2
export struct ChatHistoryListItemComp {
  @Param @Require session: ChatSession
  @Param currentSessionId: string = ''
  @Param formattedTime: string = ''
  @Param actionsDisabled: boolean = false
  @Event onSelect: (sessionId: string) => void = (_sessionId: string) => {}
  @Event onDelete: (sessionId: string) => void = (_sessionId: string) => {}
  @Local theme: ThemeState = getThemeState()
}
```

组件根节点使用 `ListItem`，迁移原来的行布局和 `.swipeAction()`。删除按钮颜色继续由 `actionsDisabled` 决定；组件只上报事件，不判断生成中、保存中或操作中 Toast。

- [ ] **Step 3: 简化 ChatHistoryDrawerComp**

空列表改为：

```ts
ChatHistoryStatusComp()
```

会话列表改为：

```ts
ForEach(this.sessions, (session: ChatSession) => {
  ChatHistoryListItemComp({
    session: session,
    currentSessionId: this.currentSessionId,
    formattedTime: this.controller.formatTime(session.updateTime),
    actionsDisabled: this.isGenerating || this.operationPending || this.isOperating,
    onSelect: (sessionId: string) => {
      this.requestSelectSession(sessionId)
    },
    onDelete: (sessionId: string) => {
      this.requestDeleteSession(sessionId)
    }
  })
}, (session: ChatSession) => session.id)
```

删除 Drawer 中已迁移的 `deleteButton` builder 和单条会话布局。保留：加载、操作锁、Toast、数据库删除、事件回传和抽屉整体结构。

- [ ] **Step 4: 检查 UI 职责边界**

运行：

```powershell
rg -n "session\.title|session\.preview|swipeAction|暂无对话记录" chat/src/main/ets/components
```

预期：

- 会话标题、预览和 `swipeAction` 只在 `ChatHistoryListItemComp.ets`。
- 空状态文案只在 `ChatHistoryStatusComp.ets`。
- `ChatHistoryDrawerComp` 不再包含单条会话的内部视觉结构。

- [ ] **Step 5: 编译验证**

执行 Hvigor debug HAP 编译，确认自定义组件作为 `List` 子节点、事件函数和 `@Param @Require` 类型均通过 ArkTS 编译。

- [ ] **Step 6: 提交本任务**

```bash
git add chat/src/main/ets/components/ChatHistoryDrawerComp.ets \
  chat/src/main/ets/components/ChatHistoryListItemComp.ets \
  chat/src/main/ets/components/ChatHistoryStatusComp.ets
git commit -m "refactor: split chat history drawer views"
```

---

### Task 4: 注释、清理与最终构建

**Files:**
- Modify: `chat/src/main/ets/controller/ChatController.ets`
- Modify: `chat/src/main/ets/controller/ChatStreamStateMachine.ets`
- Modify: `chat/src/main/ets/controller/ChatSessionSaveQueue.ts`
- Modify: `chat/src/main/ets/components/ChatTabComp.ets`
- Modify: `chat/src/main/ets/components/ChatHistoryDrawerComp.ets`
- Modify: `chat/src/main/ets/components/ChatHistoryListItemComp.ets`
- Modify: `chat/src/main/ets/components/ChatHistoryStatusComp.ets`

**Interfaces:**
- Consumes: Tasks 1–3 的最终文件。
- Produces: 注释完整、无重复职责、可构建的聊天模块。

- [ ] **Step 1: 补齐职责和并发注释**

逐文件确认：

- 文件级注释写清“负责”和“不负责”。
- 流式状态字段解释生命周期和唯一所有者。
- `requestSeq`、`finalized`、部分回复失败和队列错误恢复说明原因。
- 公共事件和方法注明参数及失败/忽略条件。
- 删除已经失效或重复的旧注释。

- [ ] **Step 2: 静态扫描无效代码**

运行：

```powershell
rg -n "\bany\b|catch\s*\([^)]*\)\s*\{\s*\}" chat/src/main/ets
rg -n "ChatStreamStateMachine|ChatSessionSaveQueue|ChatHistoryListItemComp|ChatHistoryStatusComp" chat/src/main/ets
```

预期：不新增 `any` 或空 catch；新增类型只有实际引用，没有孤立占位文件。

- [ ] **Step 3: 检查文件体积和公共 API**

运行：

```powershell
(Get-Content chat/src/main/ets/controller/ChatController.ets).Count
(Get-Content chat/src/main/ets/components/ChatTabComp.ets).Count
(Get-Content chat/src/main/ets/components/ChatHistoryDrawerComp.ets).Count
rg -n "^(export )?(class|struct)|^  (sendMessage|resendMessage|regenerate|stopGeneration)" chat/src/main/ets
```

判断标准不是固定行数，而是原文件不再包含已迁移职责，公共消息入口仍存在。

- [ ] **Step 4: 执行最终 HAP 构建**

运行项目现有 Hvigor `entry` debug `assembleHap` 命令。

预期：

- `CompileArkTS` 成功。
- `PackageHap` 成功。
- `SignHap` 成功。
- 最终输出 `BUILD SUCCESSFUL`。

- [ ] **Step 5: 检查最终差异**

```bash
git diff --check
git status --short
git diff --stat
```

确认没有修改 `NetMonitorPanel.ets`、服务端、商城、登录、路由或数据库结构。

- [ ] **Step 6: 提交清理结果**

```bash
git add chat/src/main/ets
git commit -m "docs: clarify chat state ownership"
```

- [ ] **Step 7: 向用户交付手动验证清单**

交付时列出：

1. 新增、修改文件及各自职责。
2. 流式请求、保存队列和抽屉的数据流。
3. ArkTS 与 HAP 构建结果。
4. 用户需要在 DevEco Studio 验证的发送、停止、重发、重新生成、保存、切换、新建、删除、操作锁、键盘和深色模式场景。
