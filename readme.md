# Harmony Chat Demo

一个用于学习 HarmonyOS / ArkTS / HMRouter / 多模块架构 / SSE 流式聊天的练习项目。

本项目不是单纯做一个聊天页面，而是围绕「鸿蒙应用常见工程能力」做了一套小型闭环：三 Tab 首页、游客模式、登录守卫、Dialog 路由、暗黑模式、SSE 流式输出、停止生成、会话持久化、历史记录恢复、键盘避让、多模块拆分等。

---

## 项目定位

这个仓库适合用来练习：

- HarmonyOS ArkTS 组件开发
- `@ComponentV2 / @ObservedV2 / @Trace / @Monitor`
- HMRouter 路由、拦截器、Dialog 路由
- `@Provider / @Consumer` 跨组件状态共享
- `AppStorageV2 / PersistenceV2` 全局状态与持久化状态
- `Preferences` 本地历史记录存储
- `NetworkKit` HTTP / SSE 流式请求
- MVVM + Controller + Biz + Imp 分层
- HAR 多模块拆分与模块间依赖

---

## 当前功能

### 1. 首页三 Tab 架构

应用首页由 `HomePage` 承载三个 Tab：

- 首页
- AI 助手
- 我的

`Tabs` 的 `index` 绑定到 `AppTabState.currentIndex`，当代码中修改 `currentIndex` 时，会自动切换到对应 Tab。

核心链路：

```text
HomePage
  ├── HomeTabComp
  ├── ChatTabComp
  └── ProfileTabComp
```

---

### 2. AI 聊天模块

AI 聊天模块支持：

- 输入消息
- 点击发送
- 用户消息立即进入列表
- AI 占位气泡显示「AI 思考中...」
- 后端 SSE 一段段返回文本
- AI 气泡实时追加内容，形成打字机效果
- 点击「停止」可中断当前 SSE 请求
- 点击「+ 新会话」可开启新的会话上下文

核心设计：

```text
sendMessage()
  ↓
创建 userMessage
  ↓
创建 assistant 空占位消息
  ↓
push 到 historyMessage
  ↓
activeAiMessage 指向 assistant 消息
  ↓
SSE onChunk 中 activeAiMessage.content += chunk
  ↓
@Trace content 驱动 UI 自动刷新
```

`activeAiMessage` 保存的是当前正在生成的 assistant 消息引用。它和 `historyMessage` 里的那条 AI 占位消息是同一个对象，所以每次修改 `activeAiMessage.content`，消息列表里的 AI 气泡也会同步刷新。

---

### 3. SSE 流式请求封装

项目封装了 `SseHttpUtil.postStream`：

- 使用 `http.createHttp()`
- 使用 `requestInStream()` 发起流式请求
- 监听 `dataReceive`
- 使用 `TextDecoder` 把 `ArrayBuffer` 转成字符串
- 用 buffer 累积半包数据
- 按 `\n\n` 切分 SSE 帧
- 解析 `data: {...}` JSON
- 根据帧内容触发 `onChunk / onDone / onError`

SSE 结束时会触发 `onDone`，用户点击停止时通过 `currentRequest.destroy()` 主动断开当前请求。

---

### 4. 停止生成

输入框按钮会根据 `isLoading` 自动切换：

```text
isLoading = false → 显示「发送」
isLoading = true  → 显示「停止」
```

点击停止后：

```text
ChatInputComp
  ↓
onStop
  ↓
ChatController.stopGeneration()
  ↓
currentRequest.destroy()
  ↓
activeAiMessage.content 追加 [已停止]
  ↓
isLoading = false
```

`currentRequest` 负责控制网络请求，`activeAiMessage` 负责控制当前 AI 气泡，`isLoading` 负责控制页面状态。

---

### 5. 聊天历史记录

项目支持会话持久化：

- 流式输出结束后保存当前会话
- 历史记录页展示所有会话
- 历史列表按更新时间倒序
- 支持左滑删除
- 点击历史记录后回到 AI 助手 Tab 并恢复对应会话

历史恢复链路：

```text
ChatHistoryPage 点击历史
  ↓
ChatHistoryController.openSession(sessionId)
  ↓
getChatLoadState().pendingSessionId = sessionId
  ↓
HMUtil.pop()
  ↓
HomePage 监听 pendingSessionId
  ↓
切换 Tabs 到 AI 助手 index = 1
  ↓
ChatTabComp 监听 pendingSessionId
  ↓
ChatSessionController.loadSessionById()
  ↓
读取 Preferences
  ↓
ChatMessagePlain[] 转 ChatMessage[]
  ↓
vm.historyMessage 更新
  ↓
ChatListComp 渲染历史气泡
```

---

### 6. 响应式对象与持久化对象分离

项目里有两套消息模型：

```text
ChatMessage
  UI 层使用
  @ObservedV2 + @Trace content
  用于流式更新和页面响应式刷新

ChatMessagePlain
  持久化层使用
  普通字段
  用于 JSON.stringify / JSON.parse
```

不能直接把 `ChatMessage[]` 存进 `Preferences`，因为 `ChatMessage.content` 是响应式字段，直接序列化可能导致内容丢失。

正确做法：

```text
保存时：
ChatMessage[] → ChatMessagePlain[] → JSON.stringify → Preferences

读取时：
Preferences → JSON.parse → ChatMessagePlain[] → ChatMessage[] → UI
```

---

### 7. 登录、游客模式与路由守卫

项目首页默认进入 `pages/Home`，支持游客浏览。

部分功能需要登录，例如消息记录页。未登录访问时，会触发 `AuthInterceptor`：

```text
访问 ChatHistoryPage
  ↓
AuthInterceptor 判断 hasToken()
  ↓
未登录
  ↓
push LoginPromptDialog
  ↓
拦截原跳转
```

登录状态通过 `PersistenceV2` 保存：

```text
AuthPersist
  ├── token
  ├── userName
  └── userId
```

---

### 8. Dialog 路由

登录提示不是普通 `CustomDialog`，而是 HMRouter Dialog 路由：

```text
LoginPromptDialog
  ├── 取消
  └── 去登录
```

这样可以在拦截器中通过字符串路由打开，不依赖具体页面实例。

---

### 9. 暗黑模式

项目实现了全局主题状态 `ThemeState`：

- `isDark` 控制亮色 / 暗色
- 主题状态放在 `common` 模块
- `entry` 和 `chat` 都可以复用
- 通过 `@Provider / @Consumer` 注入到子组件
- 通过 getter 统一管理颜色 token

示例：

```text
theme.bg
theme.surface
theme.textPrimary
theme.assistantBubbleBg
theme.userBubbleBg
theme.divider
```

---

### 10. 键盘避让

聊天页使用 `KeyboardController` 封装软键盘监听：

- 监听 `keyboardHeightChange`
- 把 px 转换成 vp
- 通过回调把高度交给页面
- 页面使用 `animateTo` 调整底部 padding
- 在 `aboutToDisappear` 中注销监听，避免资源泄漏

---

## 项目结构

```text
harmony-chat-demo
├── AppScope
├── entry
│   └── src/main/ets
│       ├── pages
│       │   ├── Index.ets
│       │   ├── HomePage.ets
│       │   └── LoginPage.ets
│       ├── components
│       │   ├── HomeTabComp.ets
│       │   └── ProfileTabComp.ets
│       ├── controller
│       ├── dialogs
│       │   └── LoginPromptDialog.ets
│       ├── interceptors
│       │   └── AuthInterceptor.ets
│       ├── utils
│       │   └── AuthPersist.ets
│       └── viewmodel
│           └── AppTabState.ets
│
├── chat
│   └── src/main/ets
│       ├── components
│       │   ├── ChatTabComp.ets
│       │   ├── ChatListComp.ets
│       │   └── ChatInputComp.ets
│       ├── controller
│       │   ├── ChatController.ets
│       │   ├── ChatSessionController.ets
│       │   └── ChatHistoryController.ets
│       ├── biz
│       │   └── ChatBiz.ets
│       ├── imp
│       │   └── ChatImp.ets
│       ├── models
│       │   └── chatModel.ets
│       ├── pages
│       │   ├── ChatHistoryPage.ets
│       │   └── ChatPage.ets
│       ├── utils
│       │   └── ChatPersist.ets
│       └── viewmodel
│           ├── ChatViewModel.ets
│           └── ChatLoadState.ets
│
├── common
│   └── src/main/ets
│       ├── constants
│       │   ├── ApiConstants.ets
│       │   └── HMConstants.ets
│       ├── utils
│       │   ├── HMUtil.ets
│       │   ├── HttpUtil.ets
│       │   ├── SseHttpUtil.ets
│       │   ├── KeyboardController.ets
│       │   └── WindowUtil.ets
│       ├── models
│       └── viewmodel
│           └── ThemeState.ets
│
└── server
    └── app/api
        ├── chat/route.ts
        └── login/route.ts
```

---

## 模块说明

### entry

应用入口模块，负责：

- 应用启动页
- 首页 Tabs 容器
- 登录页
- 我的页
- 登录状态
- 路由守卫
- Dialog 路由
- 向子模块提供全局主题和登录状态

### chat

聊天业务模块，负责：

- AI 聊天 UI
- SSE 消息发送
- 流式回复
- 停止生成
- 新建会话
- 历史记录
- 会话持久化
- 消息模型转换

### common

通用能力模块，负责：

- HTTP 工具
- SSE 工具
- HMRouter 工具
- 窗口 / 安全区工具
- 键盘控制器
- API 常量
- 全局主题状态

### server

本地 Next.js mock 服务，提供：

- `/api/login`
- `/api/chat`

`/api/chat` 会以 `text/event-stream` 方式逐字返回 mock 回复，用来模拟真实 AI 流式输出。

---

## 运行方式

### 1. 拉取分支

```bash
git clone -b ai-chat https://github.com/lichenyang5/harmony-chat-demo.git
cd harmony-chat-demo
```

### 2. 启动 mock 服务

```bash
cd server
npm install
npm run dev
```

服务默认运行在：

```text
http://localhost:3000
```

### 3. 修改鸿蒙端接口地址

真机无法直接访问电脑的 `localhost`，需要把接口地址改成电脑在局域网中的 IP。

文件：

```text
common/src/main/ets/constants/ApiConstants.ets
```

示例：

```ts
export class ApiConstants {
  static readonly BASE_URL: string = 'http://你的电脑局域网IP:3000'
  static readonly LOGIN: string = '/api/login'
  static readonly CHAT: string = '/api/chat'
}
```

例如：

```text
http://192.168.20.8:3000
```

### 4. 用 DevEco Studio 打开项目

打开项目根目录后：

1. 等待依赖同步
2. 配置自动签名
3. 连接真机或模拟器
4. 运行 `entry` 模块

---

## 测试账号

```text
用户名：admin
密码：123456
```

登录接口为 mock 数据，仅用于练习登录态、路由守卫和页面跳转。

---

## 核心流程图

### 发送消息

```text
ChatInputComp 点击发送
  ↓
ChatController.sendMessage()
  ↓
创建 userMessage
  ↓
创建 assistant 空占位消息
  ↓
push 到 historyMessage
  ↓
isLoading = true
  ↓
ChatBiz.sendMessageStream()
  ↓
ChatImp.sendMessageStream()
  ↓
SseHttpUtil.postStream()
  ↓
onChunk: activeAiMessage.content += chunk
  ↓
onDone: isLoading = false
  ↓
ChatSessionController.persistSession()
```

### 停止生成

```text
ChatInputComp 点击停止
  ↓
ChatController.stopGeneration()
  ↓
currentRequest.destroy()
  ↓
activeAiMessage.content += [已停止]
  ↓
activeAiMessage = null
  ↓
isLoading = false
  ↓
保存当前半截会话
```

### 恢复历史

```text
ChatHistoryPage 点击会话
  ↓
ChatHistoryController.openSession(sessionId)
  ↓
ChatLoadState.pendingSessionId = sessionId
  ↓
HMUtil.pop()
  ↓
HomePage 监听 pendingSessionId
  ↓
tabState.currentIndex = 1
  ↓
ChatTabComp 监听 pendingSessionId
  ↓
ChatSessionController.loadSessionById()
  ↓
ChatMessagePlain[] → ChatMessage[]
  ↓
vm.historyMessage = restored
```

---

## 学习重点

### 1. 为什么用 AI 空占位消息？

因为 SSE 回复是逐步返回的。发送消息时先创建一条空 assistant 消息放进列表，UI 可以立即显示「AI 思考中...」。后续每收到一个 chunk，就追加到这条消息的 `content` 上。

这样不需要额外维护一个全局 `streamingContent`，也不需要每次遍历消息列表找最后一条 assistant。

### 2. 为什么要拆 ChatMessage 和 ChatMessagePlain？

`ChatMessage` 用于 UI 响应式更新，`ChatMessagePlain` 用于持久化存储。

这能避免 `@Trace` 字段序列化丢失，也能让读取历史后重新恢复响应式能力。

### 3. 为什么历史恢复用 pendingSessionId？

`ChatTabComp` 是 HomePage 里的 Tab 组件，不是通过 HMRouter push 出来的独立页面，所以不适合直接 routeParam 传整个 `ChatSession`。

更稳的做法是：

```text
历史页只发出“要加载哪个 sessionId”的信号；
聊天 Tab 自己读取本地数据、转换对象、恢复 UI。
```

### 4. 为什么把主题放到 common？

`entry` 和 `chat` 都需要主题颜色。如果主题状态放在 `entry`，`chat` 模块不好复用；放在 `common` 后，两个模块都可以依赖它。

---

## 已知说明

- `ChatHistoryPage.ets` 是当前正在使用的历史记录页面。
- `ChatPage.ets` 更像旧的独立聊天页方案，当前主流程主要使用 `HomePage Tabs + ChatTabComp`。
- 当前服务端是 mock SSE，不是真实大模型服务。
- 当前登录是 mock 登录，不做真实鉴权。
- 当前历史记录使用 `Preferences`，适合学习和轻量数据，不适合复杂查询。

---

## 后续功能规划：从学习鸿蒙生态角度继续扩展

下面这些功能不只是“堆功能”，而是为了覆盖更多鸿蒙生态能力。

### 1. 网络状态与离线提示

学习点：

- NetworkKit 网络状态监听
- 请求失败兜底
- 离线 UI 提示
- 重试按钮

可以实现：

```text
断网时输入框上方显示「网络不可用」
发送失败的消息显示「重试」
点击重试重新发送该条消息
```

---

### 2. 使用关系型数据库替代 Preferences

学习点：

- ArkData 关系型数据库
- 表结构设计
- 会话表 / 消息表拆分
- 分页查询
- 删除会话时级联删除消息

可以把：

```text
ChatSession[]
```

拆成：

```text
session 表
message 表
```

这样更接近真实聊天 App。

---

### 3. 历史记录分页与搜索

学习点：

- List 懒加载
- 搜索框
- 防抖
- 空状态
- 数据过滤

可以实现：

```text
历史记录页支持搜索关键词
滑到底部加载更多历史会话
```

---

### 4. 消息重发与失败态

学习点：

- 消息状态设计
- loading / success / failed
- 单条消息重试
- UI 条件渲染

可以给 `ChatMessage` 增加：

```text
status: sending | success | failed | stopped
```

---

### 5. 图片选择与附件消息

学习点：

- PhotoPicker
- 权限申请
- 文件 URI
- 图片预览
- 上传接口封装

可以实现：

```text
发送图片
消息列表展示图片气泡
点击图片预览大图
```

---

### 6. 语音输入

学习点：

- 麦克风权限
- 音频录制
- 权限弹窗
- 文件保存
- 语音消息 UI

可以实现：

```text
长按录音
松开发送
消息列表展示语音气泡
```

---

### 7. 多设备适配

学习点：

- 响应式布局
- Grid / RelativeContainer
- 横竖屏适配
- 折叠屏 / 平板布局

可以实现：

```text
手机：底部 Tab
平板：左侧会话列表 + 右侧聊天详情
```

---

### 8. 通知提醒

学习点：

- 通知权限
- 本地通知
- 后台场景体验

可以实现：

```text
AI 回复完成后，如果用户不在聊天页，发送本地通知
```

---

### 9. 深色模式跟随系统

学习点：

- 系统配置变化
- 应用级主题
- 用户手动设置与系统设置的优先级

当前是手动切换暗黑模式，后续可以做成：

```text
跟随系统
浅色
深色
```

---

### 10. 单元测试与接口测试

学习点：

- Hypium
- Controller 单元测试
- SSE 解析测试
- 持久化转换测试

建议优先测：

```text
ChatMessage ↔ ChatMessagePlain 转换
SSE frame 解析
ChatSession title / preview 生成
```

---

### 11. 国际化

学习点：

- resources/base/element/string.json
- 中英文资源切换
- UI 文案集中管理

可以把：

```text
发送
停止
AI 思考中
消息记录
暂无对话记录
```

都迁移到资源文件中。

---

### 12. 应用异常与日志体系

学习点：

- HiLog
- 统一错误处理
- 崩溃日志分析
- 关键链路日志

可以实现：

```text
ChatLogger
SseLogger
PersistLogger
```

让每次发送、停止、保存、恢复都有可追踪日志。

---

## 建议学习顺序

如果目标是学习鸿蒙生态，建议按这个顺序继续做：

```text
1. 历史记录搜索
2. 消息失败重试
3. 网络状态监听
4. RDB 数据库存储
5. 图片消息
6. 平板/折叠屏适配
7. 国际化
8. 单元测试
9. 系统暗黑模式
10. 本地通知
```

这条路线能从 UI、状态、网络、存储、权限、设备适配、测试逐步覆盖鸿蒙应用开发常见能力。

---

## 适合复盘的问题

写完这个项目后，可以用下面这些问题检查自己是否真的理解：

1. 为什么 `activeAiMessage.content += chunk` 可以让列表里的 AI 气泡更新？
2. 为什么不能直接保存 `ChatMessage[]`？
3. `ChatMessagePlain` 解决的是什么问题？
4. `currentRequest.destroy()` 为什么能停止 SSE？
5. `pendingSessionId` 为什么适合做历史恢复信号？
6. `HomePage` 为什么能通过 `currentIndex = 1` 自动切到 AI 助手？
7. `@Provider / @Consumer` 和直接 import 单例状态有什么区别？
8. `Preferences` 和 RDB 分别适合什么场景？
9. `ChatController / ChatSessionController / ChatHistoryController` 分别负责什么？
10. `ChatBiz / ChatImp / SseHttpUtil` 为什么要分层？

---

## 当前分支

```text
branch: ai-chat
```

推荐把这个分支作为「鸿蒙聊天 Demo 学习分支」长期维护，每新增一个功能就配套写一篇复盘文档，逐步沉淀成自己的鸿蒙知识库。
