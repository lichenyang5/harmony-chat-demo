# Harmony Chat Demo

一个用于学习 HarmonyOS、ArkTS 和 ArkUI 的原生应用 Demo，包含商城瀑布流、本地登录、SSE 模拟聊天、业务卡片、历史会话抽屉和 RDB 持久化。

> 当前 AI 回复来自本地 Next.js Mock Server，用于演示聊天产品结构和流式交互，尚未接入真实大模型。

## 核心功能

| 模块 | 功能 |
| --- | --- |
| 首页 | 双列瀑布流、商品卡片、搜索、收藏与购物车 |
| 登录 | 单个本地演示用户、登录状态持久化、路由拦截 |
| AI 聊天 | SSE 流式回复、停止、重发、重新生成、消息状态机 |
| 业务卡片 | 确认上车点、确认行程等服务端驱动卡片 |
| 历史会话 | 聊天页右侧抽屉、切换、新建、左滑删除、当前会话恢复 |
| 本地存储 | ArkData RDB 保存会话、消息、卡片和消息状态 |
| UI 体验 | 深色模式、安全区、键盘避让、抽屉转场动画 |
| 开发调试 | 应用内 Network 悬浮球、请求记录和 SSE 帧查看 |

## 项目结构

```text
harmony-chat-demo/
├─ entry/                         # HAP 主模块
│  └─ src/main/ets/
│     ├─ components/              # 首页、我的、购物车等组件
│     ├─ pages/                   # 登录、商品、订单等页面
│     ├─ controller/              # 页面流程调度
│     ├─ interceptors/            # 登录路由守卫
│     ├─ entryability/            # UIAbility 入口
│     └─ viewmodel/               # 登录、Tab、收藏、订单状态
├─ chat/                          # 聊天 HAR 模块
│  └─ src/main/ets/
│     ├─ components/
│     │  ├─ ChatTabComp.ets       # 唯一聊天入口
│     │  ├─ ChatHistoryDrawerComp.ets
│     │  ├─ ChatListComp.ets
│     │  └─ ChatInputComp.ets
│     ├─ controller/              # 消息、会话和历史记录控制器
│     ├─ models/                  # 消息、会话、卡片和状态模型
│     ├─ biz/                     # 聊天业务接口
│     ├─ imp/                     # 聊天业务实现
│     └─ utils/ChatRdb.ets        # RDB 访问入口
├─ common/                        # 通用 HAR 模块
│  └─ src/main/ets/
│     ├─ constants/               # API、路由和公共常量
│     ├─ debug/                   # Network 调试面板
│     ├─ utils/                   # HTTP、SSE、日志、键盘、窗口工具
│     └─ viewmodel/               # 全局主题等公共状态
├─ server/                        # Next.js Mock Server
│  ├─ app/api/                    # 登录、商品、聊天等接口
│  ├─ server.js                   # HTTP 与 WebSocket 启动入口
│  └─ package.json
└─ docs/                          # 实现文章和踩坑记录
```

模块依赖保持单向：

```text
entry ──→ chat ──→ common
  └────────────────→ common

server 独立运行，通过 HTTP / SSE / WebSocket 提供 Mock 数据
```

## 技术栈

- HarmonyOS Stage Model、ArkTS、ArkUI 状态管理 V2
- HMRouter、NetworkKit、SSE、WebSocket
- ArkData RelationalStore、AppStorageV2、PersistenceV2
- HAP + HAR 多模块工程
- Next.js 16、Node.js、TypeScript

## 快速运行

### 1. 创建本机工程配置

首次克隆后，在项目根目录执行：

```powershell
Copy-Item .\build-profile.example.json5 .\build-profile.json5
```

`build-profile.json5` 只保存在本机，不会被 Git 跟踪。这样 DevEco Studio 自动生成的证书路径和签名密码不会进入仓库。

然后打开本机 `build-profile.json5`，设置后端地址：

```json5
"buildProfileFields": {
  "API_BASE_URL": "http://192.168.x.x:3000"
}
```

- HarmonyOS 真机：填写电脑的局域网 IPv4；
- 本机预览或后端同机环境：可使用 `http://127.0.0.1:3000`；
- 地址只在本机配置一次，不再修改 `ApiConstants.ets` 业务源码。

修改构建字段后，在 DevEco Studio 中选中 `common` 模块，执行 `Build > Generate Build Profile 'common'`。生成的 `BuildProfile.ets` 同样属于本机文件，不会被 Git 跟踪。

### 2. 配置本机自动签名

在 DevEco Studio 中打开 `File > Project Structure > Project > Signing Configs`，勾选 `Automatically generate signature`。DevEco Studio 会把签名材料写入本机 `build-profile.json5`，但该文件已被 Git 忽略。

### 3. 启动本地服务端

```bash
cd server
npm install
npm run dev
```

默认地址：

```text
http://localhost:3000
WebSocket: ws://localhost:3000/api/ws
```

### 4. 检查真机网络

真机中的 `localhost` 指向手机本身，因此本机 `build-profile.json5` 的 `API_BASE_URL` 必须使用电脑局域网 IPv4。

Windows 可通过以下命令查看 IPv4：

```powershell
ipconfig
```

确保电脑和手机处于同一局域网，并允许 Node.js 通过 Windows 防火墙。

### 5. 运行 HarmonyOS 应用

1. 使用 DevEco Studio 打开项目；
2. 等待 ohpm 和工程同步完成；
3. 选择 `entry` 模块；
4. 连接模拟器或真机；
5. 点击 Run 安装并启动。

### 6. 演示账号

```text
账号：admin
密码：123456
```

登录仅用于本地演示，不是生产级认证方案。

## 推荐演示流程

### 商城与收藏

1. 登录后查看首页双列瀑布流；
2. 收藏不同高度的商品卡片；
3. 在“我的收藏”中检查收藏状态；
4. 进入商品详情、购物车和结算流程。

### 流式聊天与业务卡片

1. 打开“AI 助手”；
2. 发送普通文本，观察 SSE 内容逐段更新；
3. 在生成期间测试停止、重发和重新生成；
4. 输入“打车”，查看上车点和行程确认卡片。

### 历史会话抽屉

1. 完成至少一次对话；
2. 点击聊天顶部的“历史会话”；
3. 选择会话并直接切换当前消息列表；
4. 左滑删除会话；
5. 删除当前会话后确认自动进入新会话。

## 精选文档

### 最新功能

- [聊天会话抽屉重构系列导读](./docs/33-harmony-chat-history-drawer-series-index.md)
- [签名配置本地化与 API 环境化](./docs/37-harmonyos-local-build-profile-and-api-environments.md)
- [从双页面跳转到单入口右侧抽屉](./docs/34-harmony-chat-single-entry-drawer-architecture.md)
- [RDB、会话切换、左滑删除与并发保护](./docs/35-harmony-chat-history-drawer-session-management.md)
- [隐形遮罩挡住 TextInput 的排错过程](./docs/36-arkui-invisible-overlay-blocks-textinput.md)
- [HarmonyOS 商品瀑布流首页实现](./docs/32-harmonyos-waterfall-product-feed.md)

### 聊天与工程能力

- [聊天流式状态机](./docs/30-harmony-chat-stream-state-machine-blog.md)
- [RDB 聊天记录持久化](./docs/25-arkts-rdb-chat-persistence.md)
- [失败重发、重新生成与幂等防重](./docs/28-arkts-resend-regenerate-idempotency.md)
- [应用内 Network 调试面板](./docs/26-in-app-network-monitor-sse-devtools.md)
- [ArkTS 严格类型实践](./docs/22-arkts-strict-type-system.md)
- [深色模式与系统主题](./docs/24-arkts-resources-dark-mode-follow-system.md)

`docs` 中部分早期文章记录了旧版 `ChatPage`、`ChatHistoryPage` 和 `ChatLoadState` 路由方案。当前项目结构以最新源码和 33～36 系列为准。

## 常见问题

### 真机请求 `Operation timeout`

依次检查：

- `server` 是否已运行；
- `ApiConstants.BASE_URL` 是否为电脑局域网 IPv4；
- 手机与电脑是否在同一网络；
- 防火墙是否允许 Node.js 和 3000 端口；
- 手机浏览器能否访问 `http://<电脑IP>:3000/api/products`。

### 签名提示证书过期

在 DevEco Studio 中重新生成或选择有效的自动签名配置，再执行 Clean/Rebuild。系统时间晚于证书 `NotAfter` 时，旧证书无法继续签名。签名信息只应保存在本机 `build-profile.json5`，不要提交证书、Profile、密钥库或密码。

### 输入框可见但无法唤起键盘

先检查页面上方是否仍存在透明的全屏覆盖层。`opacity(0)` 不代表组件退出触摸命中；本项目通过条件挂载，在抽屉关闭后移除整棵覆盖层。完整排错见[第 36 篇文章](./docs/36-arkui-invisible-overlay-blocks-textinput.md)。

## 当前限制

- AI 回复和业务数据主要来自本地 Mock Server；
- 仅提供单个本地演示用户；
- 主要适配手机竖屏，尚未完成平板双栏布局；
- 登录、支付、打车等流程仅用于功能演示；
- Network 调试面板只应在开发构建中使用。

## 说明

本项目用于 HarmonyOS 学习、功能验证和技术文章案例，不代表正式商业实现。
