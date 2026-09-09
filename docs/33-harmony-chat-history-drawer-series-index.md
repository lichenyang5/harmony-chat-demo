# HarmonyOS 聊天会话抽屉重构系列：从页面跳转到单入口状态管理

> 本系列基于仓库 `harmony-chat-demo` 的真实代码编写，记录一次完整的聊天模块重构：把独立的“历史消息页面”合并为聊天界面右侧抽屉，同时保留会话加载、新建、删除、RDB 持久化、流式生成保护、深色模式、安全区和键盘适配。

## 一、为什么要写成一个系列

“把历史页面改成抽屉”听起来只是一次 UI 调整，真正动手后却会碰到三个不同层次的问题：

1. **页面结构问题**：聊天 Tab、独立聊天页、历史页同时存在，谁才拥有当前会话状态？
2. **数据一致性问题**：切换、删除、新建、流式回复和 RDB 写入可能同时发生，如何避免状态串线？
3. **ArkUI 交互问题**：透明的抽屉为什么还能挡住输入框？`opacity(0)`、`zIndex` 和 `HitTestMode` 到底是什么关系？

如果把所有内容塞进一篇文章，读者很容易只记住最终代码，却没有建立解决问题的思路。因此本系列拆成三篇正文：先讲架构判断，再讲会话实现，最后复盘最隐蔽的触摸命中问题。

## 二、系列文章目录

### 第一篇：先统一状态所有权

[《HarmonyOS 聊天重构：从双页面跳转到单入口右侧抽屉》](./34-harmony-chat-single-entry-drawer-architecture.md)

这一篇重点回答：

- 为什么聊天产品不应该同时维护 `ChatTabComp` 和 `ChatPage` 两套聊天界面；
- 为什么 `pendingSessionId`、`deletedSessionId` 这类全局信号会增加理解成本；
- 如何划分 `ChatTabComp`、`ChatHistoryDrawerComp` 和 Controller 的职责；
- 为什么最终选择 `Stack + 条件挂载 + @Event`，而不是继续使用路由；
- 如何安全清理旧页面、旧路由和“我的”页面入口。

### 第二篇：把会话操作变成一条可追踪的数据流

[《HarmonyOS 会话抽屉实战：RDB、会话切换、左滑删除与并发保护》](./35-harmony-chat-history-drawer-session-management.md)

这一篇重点回答：

- 抽屉如何从 RDB 加载按更新时间倒序的会话摘要；
- 点击会话后如何更新当前 `ChatViewModel`，而不是创建第二套状态；
- 删除当前会话后为什么必须立即进入新会话；
- 为什么 AI 生成期间必须禁止切换、删除和新建；
- `sessionOperationPending` 与 `isOperating` 分别保护哪一层；
- 为什么删除会话需要数据库事务；
- `ChatMessage` 与 `ChatMessagePlain` 为什么不能混用。

### 第三篇：复盘一次“透明组件挡住键盘”的真实故障

[《ArkUI 隐形遮罩为何挡住 TextInput：zIndex、HitTestMode 与条件挂载排错》](./36-arkui-invisible-overlay-blocks-textinput.md)

这一篇重点回答：

- 为什么视觉上消失的组件仍然可能接收触摸事件；
- `HitTestMode.None` 为什么没有一次解决问题；
- 自定义组件外部的 `.zIndex(10)` 为什么会生成额外的全屏包装节点；
- 如何用 `uitest dumpLayout` 验证焦点，而不是只看“编译成功”；
- 如何通过条件挂载彻底移除遮挡层，同时保留平滑转场动画。

## 三、最终文件结构

下面只列出与本次功能直接相关的文件：

```text
harmony-chat-demo/
├─ chat/
│  ├─ Index.ets
│  └─ src/
│     ├─ main/ets/
│     │  ├─ components/
│     │  │  ├─ ChatTabComp.ets
│     │  │  ├─ ChatHistoryDrawerComp.ets
│     │  │  ├─ ChatListComp.ets
│     │  │  └─ ChatInputComp.ets
│     │  ├─ controller/
│     │  │  ├─ ChatController.ets
│     │  │  ├─ ChatSessionController.ets
│     │  │  └─ ChatHistoryController.ets
│     │  ├─ models/
│     │  │  ├─ chatModel.ets
│     │  │  └─ MessageStatus.ets
│     │  ├─ utils/
│     │  │  └─ ChatRdb.ets
│     │  └─ viewmodel/
│     │     └─ ChatViewModel.ets
│     └─ ohosTest/ets/test/
│        └─ ChatSessionController.test.ets
├─ entry/src/main/ets/
│  ├─ pages/HomePage.ets
│  ├─ components/ProfileTabComp.ets
│  └─ constants/EntryRoutes.ets
└─ docs/
   ├─ 33-harmony-chat-history-drawer-series-index.md
   ├─ 34-harmony-chat-single-entry-drawer-architecture.md
   ├─ 35-harmony-chat-history-drawer-session-management.md
   └─ 36-arkui-invisible-overlay-blocks-textinput.md
```

重构后不再存在这些运行时代码：

```text
chat/src/main/ets/pages/ChatPage.ets
chat/src/main/ets/pages/ChatHistoryPage.ets
chat/src/main/ets/viewmodel/ChatLoadState.ets
chat/src/main/ets/constants/ChatRoutes.ets
```

删除它们不是为了减少文件数量，而是为了消除重复的聊天状态所有者和不再必要的跨页面通信。

## 四、重构前后的核心差异

### 4.1 重构前：一次点击需要跨越多个页面和全局信号

```text
“我的”页面
  └─ 消息记录入口
      └─ push ChatHistoryPage
          └─ 点击某个会话
              ├─ 写入 ChatLoadState.pendingSessionId
              └─ pop 回 HomePage
                  ├─ HomePage 监听信号并切换到 AI Tab
                  └─ ChatTabComp 再监听信号
                      └─ ChatSessionController.loadSessionById()
```

删除当前会话还需要另一条 `deletedSessionId` 信号。信号消费后必须手动清空，否则同一个值再次写入时可能不会触发响应式更新。

这套流程并非不能工作，但它把一次简单的“选择会话”分散到了路由页、全局状态、首页和聊天组件四处。

### 4.2 重构后：所有操作都回到聊天容器

```text
ChatTabComp（唯一聊天入口，持有当前 ChatViewModel）
  ├─ ChatListComp
  ├─ ChatInputComp
  └─ ChatHistoryDrawerComp
      ├─ 加载摘要：ChatHistoryController → ChatRdb
      └─ 上报意图：@Event(sessionId) → ChatTabComp
          └─ ChatSessionController → 更新同一个 ChatViewModel
```

新的关键原则是：

> 历史抽屉可以发出“用户想选择哪个会话”的事件，但只有聊天总容器能够修改当前聊天状态。

这条原则让每个状态只有一个明确所有者。

## 五、职责地图

| 文件 | 负责什么 | 不负责什么 |
| --- | --- | --- |
| `ChatTabComp.ets` | 当前聊天状态、抽屉开关、会话操作串行化、键盘布局 | SQL、历史列表格式化 |
| `ChatHistoryDrawerComp.ets` | 抽屉 UI、列表状态、点击/删除/新建意图上报 | 直接替换当前 `ChatViewModel` |
| `ChatListComp.ets` | 消息列表渲染 | 会话切换 |
| `ChatInputComp.ets` | 输入与发送/停止事件 | RDB 持久化 |
| `ChatSessionController.ets` | 初始化、加载、新建、持久化当前会话 | 历史列表 UI |
| `ChatHistoryController.ets` | 查询摘要、排序、删除、时间格式化 | 当前消息列表状态 |
| `ChatRdb.ets` | 表结构、查询、保存、事务删除 | UI 状态和 Toast |
| `ChatViewModel.ets` | 当前会话 ID、消息、输入内容、生成状态 | 数据库操作 |

判断职责边界时，可以连续问三个问题：

1. 谁拥有这份状态？
2. 谁可以修改它？
3. 其他组件如何表达操作意图？

如果三个答案散落在多个页面和全局单例中，通常意味着架构仍可收敛。

## 六、功能验收范围

本次实现覆盖以下行为：

- 聊天顶部栏可直接打开右侧历史抽屉；
- 抽屉宽度约为屏幕的 80%，带遮罩和转场；
- 点击遮罩或关闭按钮退出抽屉；
- 会话摘要按更新时间倒序显示；
- 支持空状态、标题、预览、时间和当前会话标识；
- 支持左滑删除；
- 点击会话直接更新当前聊天区域，不发生路由跳转；
- 删除当前会话后自动生成新会话；
- 新建会话后清空消息和草稿，并生成新的 `sessionId`；
- AI 生成或会话持久化期间禁止危险操作；
- “我的”页面不再显示“消息记录”；
- 不再依赖 `ChatLoadState`；
- 原有发送、停止、重发、重新生成和 RDB 持久化逻辑保持原入口。

## 七、建议阅读方式

如果你主要想学习架构，按 `34 → 35 → 36` 顺序阅读。

如果你正在排查“输入框点不动”或“透明遮罩挡点击”，可以直接阅读第 36 篇，再回到第 34 篇理解为什么最终选择条件挂载。

如果你正在实现会话列表、SQLite/RDB 或流式聊天状态保护，重点阅读第 35 篇，同时可以结合仓库已有的 [《ArkTS RDB 聊天持久化》](./25-arkts-rdb-chat-persistence.md) 和 [《聊天消息状态 RDB 持久化》](./29-arkts-message-status-rdb-persistence.md)。

需要注意：`07`、`08`、`11`、`13`、`16`、`25` 等早期文章记录了项目当时的路由页面方案，其中出现的 `ChatPage`、`ChatHistoryPage` 和 `ChatLoadState` 已在本次重构中删除。它们适合用来观察项目演进，但判断当前目录结构时应以本系列和最新源码为准。

## 八、这次重构最值得带走的思路

1. **先统一状态所有权，再设计 UI。** 抽屉只是表现形式，真正的重构对象是会话状态流。
2. **组件通过事件表达意图，不要跨层直接修改别人的状态。**
3. **生成状态和数据库状态都是临界区。** 能点击不代表此刻允许执行。
4. **透明只影响绘制，不等于退出事件系统。** 覆盖层关闭后最好从组件树移除。
5. **编译成功不等于交互正确。** 焦点、键盘和触摸命中必须在设备布局树或真机上验证。

接下来从第一篇正文开始，先拆解为什么这次重构必须从“谁拥有当前会话”入手。
