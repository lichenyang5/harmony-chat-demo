# 把 demo 里的 console.log 全换成 HiLog：从 `%{private}` 没脱敏的困惑说起

> 项目：`MyApplication`（AI 助手 demo）
> 目标文件：`common/utils/LogUtil.ets`（新建）+ 全模块 11 处 console.* 替换
> 主题：入职第 4 周才意识到，工业级 ArkTS 项目里没人写 `console.log` —— 全走 HiLog。我把 demo 的 14 处 `console.log` 替换成自己封装的 `LogUtil` 的过程中，撞了一个反直觉的坑：明明写了 `%{private}s`，**用户输入的"确认打车"还是明文打到日志里了**。本篇把这次替换的全流程和那个困惑的真相一起记下来。

---

## 一、为什么要把 console.log 全换掉

之前我看过一个成熟 ArkUI 项目里的日志工具类，里面用的是：

```ts
import { hilog } from '@kit.PerformanceAnalysisKit'
hilog.info(0x0, tag, '%{public}s', value)
```

完全没有 `console.log`。我意识到一件事 —— **`console.log` 在 ArkTS 鸿蒙项目里其实是「调试垫片」，工业级项目里没人用它**。

`console.log` 的问题：

| 维度 | `console.log` | `hilog` |
|---|---|---|
| release 包 | 默认会输出，性能开销在 | 受 `hilog.isLoggable` 控制，可以编译期裁掉 |
| 隐私字段处理 | 无，全打 | `%{private}` 自动按策略脱敏 |
| 过滤能力 | 全部混在一起 | hdc 可按 domain / tag / level 过滤 |
| 输出位置 | 控制台 | 系统日志服务（journal） |
| 格式化 | 字符串拼接 | printf 风格 + 隐私标记 |

我 demo 里有 14 处 `console.log` / `console.error` / `console.warn` 散在 10 个文件里。该清了。

---

## 二、HiLog 五要素

```ts
import { hilog } from '@kit.PerformanceAnalysisKit'

hilog.info(
  0x0001,           // ① domain（业务域，16 进制）
  'ChatController', // ② tag（功能模块）
  '%{public}s',     // ③ 格式化模板
  message           // ④ 实参
)
```

### 五个等级

```ts
hilog.debug(domain, tag, format, ...args)   // 仅开发期看
hilog.info(domain, tag, format, ...args)    // 正常事件
hilog.warn(domain, tag, format, ...args)    // 异常但能继续
hilog.error(domain, tag, format, ...args)   // 影响功能
hilog.fatal(domain, tag, format, ...args)   // 致命，进程级
```

### domain（业务域）

- 取值范围 `0x0` ~ `0xFFFF`（16 位无符号）
- 团队内分段，避免互相覆盖 filter 输出
- 我 demo 整体用一个 `0x0001`，规模大的项目里通常按模块分（如 chat=0x1001 / search=0x1002）

### tag（功能标签）

- 字符串，最多 31 字节
- 一般是类名 / 文件名，hdc 抓 log 时 `--tag` 过滤
- 成熟项目里还会做 URL → tag 映射，按 host 过滤网络日志

### 格式化模板 —— 隐私符是核心

```ts
'%{public}s'   // 公开信息
'%{private}s'  // 隐私信息
'%{public}d'   // 公开整数
'%{public}f'   // 公开浮点
```

这一条直接连到下一章我撞的坑。

---

## 三、`%{private}s` 在 debug 包里没脱敏 —— 我以为是 bug

替换完 `ChatController` 里"用户发送"那条日志，我用 `iPrivate` 写的：

```ts
LogUtil.iPrivate('ChatController', '用户发送: %{private}s', input)
```

按我对 `%{private}` 的理解 —— 含隐私 → 应该自动脱敏 → 打出来应该是 `<private>`。

跑起来，IDE Log 面板里看到的是：

```text
06-10 11:57:16.043  A00001/com.example.MyApplication.ChatController
                    com.example.MyApplication  I
                    用户发送: 确认打车
```

"确认打车" 四个字**明文打出来了**。我第一反应：是不是我写错了？还是 ArkUI 这版有 bug？

去问 mentor，得到的答案让我重新理解了 HiLog 的设计哲学：

```text
%{private}s 的脱敏不是「永远脱敏」，而是「按可见性策略脱敏」：

  debug 包（开发期 / hdc 连着电脑）→ 打印明文，方便调试
  release 包（用户拿到的发布包）  → 自动显示 <private>
```

**为什么这么设计**：开发期已经能完全控制设备了，脱敏只会让我调试更难。真正的保护发生在**发布给用户**那一刻 —— 用户万一通过某种方式抓自己的日志（或者日志被中间设备截获），看不到敏感字段。

记住一句：

> `%{private}` 是给"日志泄漏出去"那一刻准备的，不是给开发者看的。

### 怎么验证 release 包确实脱敏

```text
1. 打 release 签名包
2. 设备上跑 / hdc shell hilog -t ChatController 抓日志
3. 那一行变成 "用户发送: <private>"
```

平时不用打 release 包验证，记住"按可见性策略"这个机制就行。

### 哪些字段一定要 `%{private}`

```text
手机号 / token / 验证码 / 用户输入 / 地址 / openid / IDFA / 邮箱 / 身份证
```

口诀：**只要这个字段最终进数据库、进用户视野、或由用户输入 → 一定 `%{private}s`**。

---

## 四、HiLog 单条 ~1024 字节硬上限

我以为日志想多长打多长。结果看到一份成熟的日志封装里：

```ts
private static printLength = 600

private static logContent(content: string, tag?: string) {
  // ...
  let split: string[] = content?.split("\n")
  split?.forEach((value) => {
    hilog.info(0x0, tag, '%{public}s', value)
  })
}
```

把字符串按 600 字符切了。**为什么**？

HiLog 单条日志在系统层有大约 1024 字节的硬上限（含 tag、format、domain 等开销，留给 message 的大概 ~600）。**超出的部分被直接截断，不报警**。

最容易踩坑的场景：

```ts
// 打印一个大对象 JSON
LogUtil.i('Chat', JSON.stringify(bigPayload))   // 可能被截成一半
```

要是不切，"用户消息" / "请求 body" / "响应 JSON" 这种长内容一旦超过上限，**你在 IDE 里看到的是不完整的日志**，但又没有任何报错。最难排查的就是这种。

我的 LogUtil 里的 split 实现：

```ts
private static split(s: string): string[] {
  if (s.length <= MAX_LEN) return [s]
  const arr: string[] = []
  for (let i = 0; i < s.length; i += MAX_LEN) {
    arr.push(s.slice(i, i + MAX_LEN))
  }
  return arr
}
```

每个 API 调用前都过一遍 split，超长就拆多条。

---

## 五、tag 怎么取：去掉文本里的冗余前缀

我以前的 console.log 习惯：

```ts
console.log('[AuthInterceptor] 已登录，放行')
console.error('[ChatPersist] loadSessions failed', JSON.stringify(e))
```

文本里加 `[Xxx]` 前缀，方便 grep 定位。但换成 HiLog 后**这个习惯要丢掉**：

```ts
// ❌ 旧习惯：文本里带类名
LogUtil.i('AuthInterceptor', '[AuthInterceptor] 已登录，放行')

// ✅ 正确：tag 已经承载了类名，文本干净
LogUtil.i('AuthInterceptor', '已登录，放行')
```

**为什么**：

- 日志输出格式是 `A0001/AuthInterceptor: 已登录，放行` —— tag 已经在前缀里
- 文本里再加 `[AuthInterceptor]` 是冗余
- hdc filter 用 `--tag=AuthInterceptor` 直接过滤，比文本搜索快得多

---

## 六、我的 LogUtil 封装

放在 `common/src/main/ets/utils/LogUtil.ets`，整段：

```ts
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0001
const MAX_LEN: number = 600

export class LogUtil {
  /** 调试日志，release 包默认不输出 */
  static d(tag: string, msg: string): void {
    LogUtil.split(msg).forEach((s) => hilog.debug(DOMAIN, tag, '%{public}s', s))
  }

  /** 普通信息 */
  static i(tag: string, msg: string): void {
    LogUtil.split(msg).forEach((s) => hilog.info(DOMAIN, tag, '%{public}s', s))
  }

  /** 警告 */
  static w(tag: string, msg: string): void {
    LogUtil.split(msg).forEach((s) => hilog.warn(DOMAIN, tag, '%{public}s', s))
  }

  /** 错误 + 可选异常栈 */
  static e(tag: string, msg: string, err?: Error): void {
    const body = err ? `${msg} | ${err.message}\n${err.stack ?? ''}` : msg
    LogUtil.split(body).forEach((s) => hilog.error(DOMAIN, tag, '%{public}s', s))
  }

  /** 含隐私字段的日志：调用方 format 用 %{private}s，release 自动脱敏 */
  static iPrivate(tag: string, format: string, sensitive: string): void {
    hilog.info(DOMAIN, tag, format, sensitive)
  }

  private static split(s: string): string[] {
    if (s.length <= MAX_LEN) return [s]
    const arr: string[] = []
    for (let i = 0; i < s.length; i += MAX_LEN) {
      arr.push(s.slice(i, i + MAX_LEN))
    }
    return arr
  }
}
```

记得在 `common/Index.ets` 里 export：

```ts
export { LogUtil } from './src/main/ets/utils/LogUtil'
```

5 个 API：

| API | 何时用 |
|---|---|
| `d(tag, msg)` | 开发期调试，release 包不输出 |
| `i(tag, msg)` | 普通信息流 |
| `w(tag, msg)` | 异常但能继续（如 session not found） |
| `e(tag, msg, err?)` | 错误，可带 Error 对象自动拼 stack |
| `iPrivate(tag, format, sensitive)` | 含隐私字段，format 必须用 `%{private}s` |

---

## 七、替换 11 处 console.* 的实战经验

### 7.1 替换映射规则

```text
console.log         → LogUtil.i
console.warn        → LogUtil.w
console.error       → LogUtil.e（带 Error 对象时第三参数传 Error）
含隐私字段的 log    → LogUtil.iPrivate（format 写 %{private}s）
```

### 7.2 替换前后对比

**例 1**：拦截器普通日志

```ts
// 改前
console.log('[AuthInterceptor] 已登录，放行')

// 改后
LogUtil.i('AuthInterceptor', '已登录，放行')
```

**例 2**：catch 里 error + 异常 JSON

```ts
// 改前
console.error('[ChatPersist] loadSessions failed', JSON.stringify(e))

// 改后
LogUtil.e('ChatPersist', 'loadSessions failed: ' + JSON.stringify(e))
```

注意：`e` 是 `catch (e)` 的，类型不一定是标准 `Error`，所以**没传给 `err?: Error` 参数**，而是 `JSON.stringify` 拼到 msg 里。

**例 3**：含用户输入

```ts
// 改前（user input 直接打）
console.log('用户发送:', input)

// 改后（用 iPrivate）
LogUtil.iPrivate('ChatController', '用户发送: %{private}s', input)
```

### 7.3 import 路径分两类

- **common 模块内部**（`WindowUtil` / `SseHttpUtil` / `KeyboardController`）→ 相对 import
  ```ts
  import { LogUtil } from './LogUtil'
  ```
- **chat / entry 模块**（业务文件）→ 走模块名
  ```ts
  import { LogUtil } from 'common'
  ```
  如果文件已经从 `'common'` import 过别的东西，把 LogUtil 加到同一行：
  ```ts
  import { WindowUtil, LogUtil } from 'common'
  ```

### 7.4 这次的完整替换清单

| 文件 | 替换数 |
|---|---|
| `common/utils/WindowUtil.ets` | 1 处 error |
| `common/utils/SseHttpUtil.ets` | 1 处 error |
| `common/utils/KeyboardController.ets` | 1 处 error |
| `chat/utils/ChatPersist.ets` | 3 处 error |
| `chat/controller/ChatController.ets` | 1 处 error |
| `chat/controller/ChatSessionController.ets` | 1 处 warn |
| `chat/pages/ChatHistoryPage.ets` | 1 处 log |
| `entry/pages/HomePage.ets` | 1 处 log |
| `entry/interceptors/AuthInterceptor.ets` | 2 处 log |
| `entry/interceptors/SameRouteInterceptor.ets` | 2 处 log |

替换完用 grep 全局扫一次确认 0 残留：

```bash
grep -rn "console\." --include="*.ets" .
```

### 7.5 跑一次确认效果

IDE Log 面板里 filter `--tag=AuthInterceptor`，应该看到：

```text
A0001/AuthInterceptor:           已登录，放行
A0001/SameRouteInterceptor:      from=HomePage, target=ChatPage
A0001/ChatController:            用户发送: 确认打车         ← debug 包明文（正常）
A0001/ChatPersist:               loadSessions failed: ...
```

`A0001` 是 domain (`0x0001`)，后面是 tag → 消息。比之前 `console.log` 一坨混在一起清晰多了。

---

## 八、为什么我没学 HiAppEvent

我看过的一个成熟 ArkTS 项目里有埋点系统，但**没直接调 `hiAppEvent.write`** —— 而是在业务层和上报通道之间包了一层抽象的事件管线：

```text
业务代码
    ↓ 调 helper.onSomething(...)
事件汇集层 helper.emit(event)
    ↓ ① LogUtil 出可读日志（开发自查）
    ↓ ② callback(event)            （业务事件透传）
外层注入的 sink
    ↓
项目自选的私有上报通道
```

也就是说，工业级项目通常会包一层 **事件管线 + 抽象上报通道**，业务代码不感知具体上报实现。`hiAppEvent.write` / `addWatcher` 那套裸 API 我 demo 用不上。

按"遇到问题再学"的原则，HiAppEvent 暂时跳过。等真的要接的时候再补。

---

## 九、一句话心智模型

```text
HiLog 五件套：等级 + domain + tag + 格式化 + 隐私符。
%{private} 不是「永远脱敏」，是「release 时脱敏」。
单条 1024 字节硬上限，长内容自己切。
tag 写类名，文本里别再加 [Tag] 前缀。
工程项目里业务代码不直接调 hilog，统一包一层 LogUtil。
```

---

## 十、顺口溜

```text
五级日志 debug info warn error fatal，
域加标签隐私符，长串分段六百到。

私有不是真脱敏，是 release 那一刻；
debug 看明文，方便我调试。

tag 写类名不重复，文本里别再加前缀；
模块内部相对 import，跨模块走模块名。
```

---

## 十一、参考

- [HiLog API（@kit.PerformanceAnalysisKit）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-hilog)
- [HiAppEvent 应用事件框架](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hiappevent-watcher)（等碰到再看）
