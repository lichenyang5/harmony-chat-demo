# 聊天组件职责拆分设计

## 背景

当前聊天功能已经具备发送、停止、失败重发、重新生成、历史会话切换、新建、删除和 RDB 持久化能力，但以下文件同时承担了较多职责：

- `chat/src/main/ets/controller/ChatController.ets`
- `chat/src/main/ets/components/ChatTabComp.ets`
- `chat/src/main/ets/components/ChatHistoryDrawerComp.ets`

本次只重构聊天相关代码。`common/src/main/ets/debug/NetMonitorPanel.ets` 留到下一阶段单独设计和实施。

## 目标

在不改变现有 UI、交互、RDB 表结构、路由和组件对外行为的前提下：

1. 将流式请求生命周期从 `ChatController` 中抽离。
2. 将会话保存串行化逻辑从 `ChatTabComp` 中抽离。
3. 将历史会话列表项和空状态从抽屉容器中抽离。
4. 明确运行时状态的唯一所有者。
5. 为业务入口、状态字段、并发保护和错误语义补充有效注释。

## 非目标

- 不调整页面视觉样式、尺寸、颜色或动画。
- 不修改发送、停止、重发、重新生成的交互语义。
- 不修改会话标题、预览、排序、删除或切换规则。
- 不修改 `ChatRdb` 数据库结构和持久化格式。
- 不修改服务端、商城、登录、路由和 Network 调试面板。
- 不在本阶段新增自动化测试文件或进行真机交互测试。

## 方案选择

采用“保留门面、向下委托”的方案：

```text
ChatTabComp
├─ ChatController
│  └─ ChatStreamStateMachine
├─ ChatSessionController
├─ ChatSessionSaveQueue
└─ ChatHistoryDrawerComp
   ├─ ChatHistoryListItemComp
   └─ ChatHistoryStatusComp
```

`ChatController` 继续作为消息操作的唯一公共入口，避免 `ChatListComp`、`ChatInputComp` 和 `ChatTabComp` 改用多个控制器。流式运行时、保存队列和抽屉展示细节分别下沉到独立单元。

## 文件结构

### 新增文件

```text
chat/src/main/ets/controller/ChatStreamStateMachine.ets
chat/src/main/ets/controller/ChatSessionSaveQueue.ts
chat/src/main/ets/components/ChatHistoryListItemComp.ets
chat/src/main/ets/components/ChatHistoryStatusComp.ets
```

### 修改文件

```text
chat/src/main/ets/controller/ChatController.ets
chat/src/main/ets/components/ChatTabComp.ets
chat/src/main/ets/components/ChatHistoryDrawerComp.ets
```

只有在模块导出入口确实需要公开新增类型时才修改对应 `Index.ets`；抽屉内部组件默认保持模块内引用，不扩大公共 API。

## 状态所有权

### ChatController

继续公开以下接口：

- `sendMessage()`
- `resendMessage(target)`
- `regenerate(target)`
- `stopGeneration()`

它负责：

- 校验操作是否允许执行。
- 创建或复用用户消息与 AI 消息。
- 计算消息在列表中的位置。
- 构造不包含当前轮次的历史上下文。
- 将准备好的轮次交给流式状态机。

它不再持有 HTTP 请求、活动消息、请求序号和终态幂等标记。

### ChatStreamStateMachine

它是单次流式请求运行时状态的唯一所有者，持有：

- 当前 `http.HttpRequest`。
- 当前用户消息和 AI 消息引用。
- 单调递增的请求序号。
- 当前请求是否已经结束。
- 当前失败是否允许将用户消息标记为可重发。

它负责：

- 调用 `ChatBiz.sendMessageStream()`。
- 处理首个 chunk、后续 chunk、done、网络错误和空回复。
- 过滤停止后或新请求开始后的过期回调。
- 保证一次请求只能成功或失败收尾一次。
- 处理中途失败时的部分回复语义。
- 中断 HTTP 请求并把消息状态调整为 `STOPPED` / `DONE`。
- 统一清理活动引用并更新 `vm.isLoading`。

### ChatSessionSaveQueue

它只拥有保存任务的 Promise 队列和待执行任务计数，不持有响应式 UI 状态、会话列表或数据库上下文。

对外提供一个入队方法，接收 `() => Promise<void>` 保存任务并返回当前任务对应的 Promise。新任务必须在前一个任务成功或失败后执行；前一个任务失败不能让队列永久处于 rejected 状态。队列在第一个任务进入和最后一个任务结束时，通过忙闲回调通知调用方。

`ChatTabComp` 继续拥有响应式字段 `sessionOperationPending`，并根据队列的忙闲回调更新它。会话加载和抽屉删除仍复用同一个页面级繁忙状态，因此页面交互锁规则不变。

### ChatTabComp

仅持有页面级状态：

- `ChatViewModel`
- 键盘高度
- 历史抽屉可见性
- 会话操作繁忙状态
- 主题状态

它负责组装控制器、生命周期、键盘避让、抽屉动画、Toast 和组件事件连接，不直接实现 SSE 状态推进或 Promise 队列算法。

### ChatHistoryDrawerComp

持有历史列表数据和抽屉内部操作锁，负责：

- 抽屉显示时刷新会话列表。
- 调用 `ChatHistoryController` 加载与删除。
- 拦截生成中或会话操作中的用户动作。
- 将选择、新建、关闭和删除当前会话的意图回传给 `ChatTabComp`。

它不再绘制单条会话的内部结构，也不再直接绘制空状态。

### ChatHistoryListItemComp

只渲染一个 `ChatSession`：头像文字、标题、预览、更新时间、当前会话标记和左滑删除按钮。组件通过事件上报选择和删除意图，不加载数据、不访问 RDB、不显示 Toast。

### ChatHistoryStatusComp

只渲染抽屉空状态，保持现有图标和三行文案不变。由于本次是纯重构，不新增加载失败页面；已有删除失败和操作锁提示继续使用 Toast。

## 数据流

### 流式消息

```text
ChatInputComp / ChatListComp
  → ChatController 校验、准备消息和历史上下文
  → ChatStreamStateMachine.start(...)
  → ChatBiz / SSE
  → 状态机处理 chunk / done / error
  → ChatViewModel 与 ChatMessage 响应式更新
  → vm.isLoading=false
  → ChatTabComp 的 Monitor 请求保存
```

### 会话保存

```text
ChatTabComp.onLoadingChange()
  → ChatSessionSaveQueue.enqueue(saveTask)
  → 队列忙闲回调更新 sessionOperationPending
  → 按 FIFO 顺序调用 ChatSessionController.persistSession()
  → 当前保存完成
  → 队列清空后回调 sessionOperationPending=false
```

### 历史抽屉

```text
ChatHistoryDrawerComp.loadData()
  → sessions
  → ChatHistoryListItemComp / ChatHistoryStatusComp
  → 选择或删除事件回传 Drawer
  → Drawer 执行操作锁与控制器调用
  → ChatTabComp 负责加载、重置当前会话及关闭抽屉
```

## 错误与并发规则

- 生成中继续禁止切换、删除和新建会话。
- 保存、加载或删除进行中继续禁止冲突操作。
- `requestSeq` 变化后，旧 SSE 回调不得修改消息列表。
- `finalized` 保证 `onDone` 和 `onError` 不会重复收尾。
- 部分文本已经到达后失败，用户消息保持成功，AI 消息进入失败状态。
- 未收到任何 AI 内容且允许重发时，用户消息进入失败状态并移除空 AI 占位。
- 会话保存任务失败后，后续保存任务仍可继续运行。
- 现有 Toast 文案保持不变。

## 注释规范

- 每个新文件顶部说明职责、依赖和明确不负责的事项。
- 每个状态字段注明所有者及其生命周期。
- 公共方法写明参数、返回值和失败语义。
- 对请求序号、幂等终态、部分回复失败、保存队列恢复等非直观逻辑解释原因。
- 不为普通布局尺寸、字体设置和简单事件绑定添加逐行复述式注释。

## 迁移顺序

1. 新增 `ChatStreamStateMachine`，迁移 HTTP 请求与终态逻辑。
2. 修改 `ChatController`，保留公共 API 并委托状态机。
3. 新增 `ChatSessionSaveQueue`，修改 `ChatTabComp` 的保存委托。
4. 新增历史列表项和状态组件，修改抽屉容器组装方式。
5. 清理重复字段、方法和无效 import。
6. 扫描注释、循环依赖和公共 API 是否符合设计。
7. 执行 ArkTS 编译及 HAP 构建。

## 验证边界

本次由实现方执行：

- ArkTS 编译。
- HAP 构建。
- 无效 import、空 catch、`any` 和意外公共导出的静态扫描。

由用户在 DevEco Studio 中手动验证：

- 正常发送及流式显示。
- 停止生成。
- 失败消息重新发送。
- AI 消息重新生成。
- 会话自动保存。
- 打开和关闭历史抽屉。
- 历史会话切换、新建和左滑删除。
- 删除当前会话后自动进入新会话。
- 生成中及保存中操作锁提示。
- 键盘避让、深色模式和安全区表现。

## 后续阶段

聊天重构通过手动验证后，再为 `NetMonitorPanel.ets` 单独进行职责分析、设计确认和实施。该阶段不复用本设计中的状态类，也不与聊天重构混合提交。
