# CLAUDE.md — harmony-chat-demo

> This file is for Claude Code / AI coding assistants.
> 目标：让 AI 在修改本仓库时先理解项目定位、架构边界和不可破坏的规则。

## 1. 项目定位

`harmony-chat-demo` 是一个 HarmonyOS / ArkTS 学习与工程实践 Demo。

它不是单纯 UI 练习，而是围绕「AI 聊天」这个场景，串起：

- ArkUI 聊天页面
- SSE 流式响应
- 结构化卡片消息
- 消息状态机
- 失败重发 / 重新生成
- RDB 本地持久化
- 网络调试与日志
- ArkTS 工程分层

这个项目的核心价值是：**把 AI 回复从普通文本扩展为可持久化、可恢复、可渲染的结构化消息链路。**

## 2. 主要演示链路

用户输入一句话，例如「打车」：

```text
用户输入
→ 创建用户消息和 AI thinking 消息
→ 调用本地 /api/chat
→ SSE 返回 chunk
→ 最后一帧返回 done + card payload
→ 前端按 type 解析
→ ArkUI 渲染文本 / 卡片
→ RDB 保存消息和卡片 payload
→ 下次进入页面恢复历史消息
```

修改代码时要始终围绕这条链路思考，不要只改 UI 表象。

## 3. 技术关键词

- HarmonyOS
- ArkTS
- ArkUI
- Stage Model
- @ComponentV2
- @State / @Trace / @Local
- SSE
- AI Chat
- Message Status
- RDB
- Preferences 迁移到 RDB
- MVVM
- Controller / ViewModel / Model
- Card Type Rendering
- HiLog
- Network Debugging

## 4. 建议阅读顺序

改代码前，优先阅读这些文件或目录：

```text
entry / chat 模块入口
src/main/ets/pages
src/main/ets/components
src/main/ets/viewmodel
src/main/ets/model 或 models
src/main/ets/controller
src/main/ets/common
src/main/ets/database 或 rdb 相关目录
docs
README.md
```

如果文件名与上述不完全一致，请按项目实际目录理解，不要机械新增重复目录。

## 5. 架构原则

本项目应保持分层清晰：

```text
UI Component
→ ViewModel
→ Controller
→ Service / Repository
→ Network / RDB / Common
```

### UI 层

UI 层只负责：

- 展示消息
- 展示卡片
- 响应点击
- 根据状态显示 loading / error / retry

UI 层不要直接写复杂网络请求、RDB SQL、SSE 解析逻辑。

### ViewModel 层

ViewModel 负责：

- 页面状态
- 消息列表
- 当前输入
- loading / streaming / error 状态
- 调用 Controller

### Controller 层

Controller 负责：

- 发送消息
- 流式响应编排
- 重发 / 重新生成
- 中断 / 错误处理
- 协调持久化

### Model 层

Model 负责：

- ChatMessage
- Card payload
- MessageStatus
- 序列化 / 反序列化
- fromPlain / toPlain

### RDB 层

RDB 负责：

- 会话
- 消息
- 卡片 payload
- 消息状态
- 历史恢复

不要回退到只用 Preferences 保存聊天历史。

## 6. 消息状态规则

不要用一堆 boolean 表示消息状态，例如：

```text
isLoading
isError
isDone
isStreaming
```

优先使用统一状态枚举：

```text
SENDING
THINKING
STREAMING
DONE
ERROR
```

判断终态时应使用统一函数，例如：

```text
isTerminal(status)
```

规则：

- `STREAMING` 不是终态
- `DONE` 是成功终态
- `ERROR` 是失败终态
- 用户侧失败和 AI 侧失败要区分
- 有半截流式内容时，失败处理不能直接清空内容

## 7. SSE 处理规则

SSE 是流式过程，不要把中间态和最终态混在一起。

推荐理解：

```text
onChunk：更新 AI 文本内容
onDone：处理最终 meta / card / error
onError：处理网络错误或解析错误
```

注意：

- 最后一帧可能带 `card`
- 最后一帧可能带 `meta.error`
- 不要在第一个 chunk 就把消息标记为 DONE
- 不要吞掉 done 帧中的错误信息
- 流式失败时要保留已有半截内容

## 8. 卡片渲染规则

卡片不应该靠文本内容猜测，而应该靠协议字段。

推荐结构：

```text
message.type = text | card
card.type = pickup_confirm | trip_confirm | quick_questions | ...
card.payload = {...}
```

渲染时：

```text
card.type → 对应 ArkUI 组件
```

不要在 UI 里硬编码大量 if 文本判断。

卡片数据必须能：

- 首次渲染
- RDB 保存
- 历史恢复
- 字段缺失时不崩溃

## 9. RDB 持久化规则

聊天历史要保存的不只是文本，还包括：

- role
- content
- status
- type
- cardType
- cardPayload
- createdAt / updatedAt
- error 信息

读取时要转换回可观察的模型对象。

不要把 Observable 对象直接粗暴 JSON 化后写入数据库，应使用模型自己的转换方法。

## 10. 网络调试规则

真机调试时不能依赖浏览器 DevTools。

如需新增调试能力，应优先做到：

- 请求 URL
- method
- request headers
- request body
- response status
- response body
- duration
- error message
- 一键复制 JSON / curl

不要把 token、内网地址、公司接口写死到仓库。

## 11. UI 修改规则

可以优化 UI，但不要破坏业务链路。

UI 优先级：

1. 消息状态清晰
2. 错误可见
3. 重试入口明确
4. 卡片字段缺失不崩
5. 历史恢复一致
6. 视觉简洁

不要为了视觉效果改动 Controller、RDB 或协议逻辑。

## 12. 代码风格

- 使用 ArkTS 严格类型
- 避免 `any`
- 减少魔法字符串
- action / type / status 用枚举或常量
- 复杂逻辑写注释
- 函数职责单一
- 不要把大段逻辑塞进 build()
- 组件样式可以先写死，但要集中管理关键常量

## 13. AI 协作边界

AI 修改代码时必须遵守：

- 不要删除现有功能
- 不要擅自替换架构
- 不要把 RDB 改回 Preferences
- 不要把状态机改回多个 boolean
- 不要把卡片协议改成纯文本判断
- 不要改动接口协议除非 README / docs 同步
- 不要生成无法编译的伪代码
- 不要为了“看起来简单”把分层合并

## 14. 敏感信息规则

禁止提交：

- 公司项目名
- 公司接口
- 内网 IP
- token
- cookie
- 真实用户数据
- 埋点字段细节
- 私有业务协议

所有示例使用：

```text
localhost
example.com
mock
demo
```

## 15. 推荐提交粒度

每次提交只做一类事情：

```text
feat(chat): add card payload persistence
fix(stream): handle done frame meta error
refactor(message): move plain conversion into model
docs(readme): explain chat message lifecycle
style(card): polish pickup confirm card UI
```

不要一个提交同时改 UI、RDB、协议、README 和路由。

## 16. 修改后检查

每次修改后至少检查：

```text
1. 项目是否能编译
2. 发送文本消息是否正常
3. 输入“打车”是否能返回卡片
4. SSE 中间态是否正常显示
5. done 帧是否正确处理
6. 历史记录是否能恢复
7. 卡片历史是否能恢复
8. 失败重发 / 重新生成是否仍可用
9. README / docs 是否需要同步
```

## 17. 面试讲解口径

这个项目可以这样介绍：

> 这是一个 HarmonyOS AI 聊天 Demo。我没有只做普通聊天气泡，而是把后端 SSE 流式返回、前端消息状态机、结构化卡片渲染、RDB 持久化和历史恢复串成了一条完整链路。重点是理解 AI 回复不一定只是文本，也可以是可持久化、可恢复的业务卡片。

## 18. 后续增强方向

优先级从高到低：

1. 更完整的消息状态可视化
2. 网络调试面板增强
3. 卡片协议版本管理
4. RDB migration
5. 请求重放
6. 更多结构化卡片
7. 单元测试 / mock 测试
8. README 补架构图和演示 GIF
