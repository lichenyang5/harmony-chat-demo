# 给 ArkTS 应用做一个内置的「Network 面板」：实时看清 SSE 每一帧和最后那张卡片

> 项目：`MyApplication`（AI 助手 demo）
> 新增文件：`common/utils/debug/NetMonitor.ets`（数据层）+ `NetMonitorPanel.ets`（UI 层）
> 改动文件：`common/utils/HttpUtil.ets`、`SseHttpUtil.ets`（埋钩子）+ `common/Index.ets`（导出）+ `entry/pages/Index.ets`（挂悬浮球）
> 主题：调打车对话时，我特别想知道两件事 —— **我到底给后端发了什么**、**SSE 最后一帧返回的 card 长什么样**。HiLog 里翻日志太碎，DevEco Profiler 的 Network 又看不清业务 JSON。于是我照着浏览器 DevTools 的 Network 面板，给 App 内置了一个：一个悬浮球，点开能看每条请求的请求体、流式每一帧、拼出来的回复、以及结束帧的卡片数据。本篇记录这个调试工具的完整实现和踩的几个坑。

---

## 一、为什么不直接用现成的

调 AI 打车这条链路时，我的真实困惑是：

```text
输入「打车」→ 流式吐字 → 最后弹出一张「确认上车点」卡片
```

卡片不对的时候，我想知道：是后端 done 帧里 `card` 字段就错了，还是我前端解析错了？这就要看到**原始报文**。我试过三条路，都不顺手：

| 方案 | 问题 |
|---|---|
| `LogUtil` 打日志 | SSE 一帧一条 log，几十条混在 HiLog 里，还有 600 字符切段，拼不回完整 JSON |
| DevEco Profiler → Network | 只连真机、不支持模拟器；偏重「耗时/数据量」性能视角，看业务 JSON 不直观 |
| Charles 抓包 | `@ohos.net.http` 默认不走系统代理（`usingProxy` 默认 `false`），要改代码开代理才抓得到，绕 |

我真正想要的是浏览器按 `F12` → Network 那种体验：**一条请求一行，点开看 Headers / Payload / Response / 流式 EventStream**。鸿蒙没有内置这东西，那就自己做一个最小版。

目标定得很克制：

```text
1. 一个悬浮球，平时不挡事，点开是半屏面板
2. 列表：每条请求一行（方法 / 路径 / 耗时 / 状态 / 帧数）
3. 详情：请求体、流式每一帧、chunk 拼出的全文、done 帧的 card、错误
4. SSE 流式过程中实时刷新，不用等结束
5. 只在 debug 包出现，release 包零痕迹
```

---

## 二、整体设计：一个数据单例 + 一个 UI 覆盖层 + 两个埋点

```text
                  ┌─────────────────────────────┐
业务层 (chat)      │  ChatImp.sendMessageStream  │   完全不动
                  └──────────────┬──────────────┘
                                 │
                  ┌──────────────▼──────────────┐
统一网络出口       │  SseHttpUtil / HttpUtil     │   ← 在这里埋钩子
       (common)   │  begin / addFrame / finish  │
                  └──────────────┬──────────────┘
                                 │ 上报
                  ┌──────────────▼──────────────┐
数据层 (单例)      │  NetMonitorState            │   @ObservedV2 + @Trace
                  │  records: NetRecord[]       │
                  └──────────────┬──────────────┘
                                 │ 读取
                  ┌──────────────▼──────────────┐
UI 层 (覆盖层)     │  NetMonitorOverlay          │   悬浮球 + 半屏面板
                  │  挂在 entry 根页面 Stack 顶层 │
                  └─────────────────────────────┘
```

关键决定：**钩子只埋在 `common` 里那两个唯一的网络出口**（普通请求走 `HttpUtil`，流式走 `SseHttpUtil`）。业务层 `ChatImp` / `ChatController` 一行都不用改 —— 这是把网络收口到统一工具类的好处，加监控只动一个地方。

涉及文件：

| 文件 | 作用 |
|---|---|
| `common/src/main/ets/debug/NetMonitor.ets` | **新增**：记录模型 `NetRecord` / `NetFrame` + 全局单例 `NetMonitorState` |
| `common/src/main/ets/debug/NetMonitorPanel.ets` | **新增**：悬浮球 `NetMonitorOverlay` + 半屏面板 + 详情页 |
| `common/src/main/ets/utils/SseHttpUtil.ets` | 埋钩子：begin → 每帧 addFrame → done 帧抓 card → 收尾 |
| `common/src/main/ets/utils/HttpUtil.ets` | 埋钩子：begin → finish / fail |
| `common/Index.ets` | 导出 `getNetMonitor` / `NetMonitorOverlay` |
| `entry/src/main/ets/pages/Index.ets` | 根页面 `Column` → `Stack`，把悬浮球盖在所有页面之上 |

---

## 三、数据层：用 @Trace 让流式帧「自己跳出来」

整个面板能实时刷新的核心，是 ArkUI V2 的响应式：把会变化的字段标 `@Trace`，UI 读了它就会在它变化时自动重渲染。

### 3.1 两个记录模型

```ts
/** SSE 单帧记录：一帧定下来就不再改，所以是普通 class */
export class NetFrame {
  seq: number = 0        // 帧序号，从 1 开始
  offsetMs: number = 0   // 距请求开始的毫秒偏移
  type: string = ''      // chunk / done / raw（raw = JSON 解析失败的原始帧）
  data: string = ''      // data: 后面的原始 JSON 文本
}

/** 一次请求的完整记录：会随请求推进而变的字段加 @Trace */
@ObservedV2
export class NetRecord {
  id: number = 0
  method: string = ''        // GET / POST / SSE
  url: string = ''
  startTime: number = 0
  requestBody: string = ''
  @Trace status: string = 'pending'   // pending / streaming / done / error
  @Trace httpCode: number = 0
  @Trace durationMs: number = 0
  @Trace responseBody: string = ''     // 普通请求的响应体
  @Trace frames: NetFrame[] = []       // SSE 帧列表
  @Trace fullText: string = ''         // chunk 拼接出的完整回复
  @Trace cardJson: string = ''         // done 帧附带的卡片 JSON
  @Trace errorMsg: string = ''
}
```

设计取舍：

- `NetFrame` 不加 `@ObservedV2`，因为一帧的内容到达后就是只读的，没必要为它建响应式代理。**真正变化的是 `NetRecord.frames` 这个数组本身**（不断 push 新帧），所以 `frames` 标 `@Trace` 就够 —— 数组引用变化会触发列表重渲染。
- `method` / `url` / `requestBody` / `startTime` 这些请求一开始就定死的字段**不标** `@Trace`，省掉无谓的响应式开销。

### 3.2 全局单例

`common` 是整个 App 里的单实例 HAR，`entry` 和 `chat` 拿到的是同一个对象，所以一个模块级单例就能跨模块共享：

```ts
@ObservedV2
export class NetMonitorState {
  @Trace enabled: boolean = BuildProfile.DEBUG  // 采集开关，跟随构建模式
  @Trace panelVisible: boolean = false          // 面板是否展开
  @Trace records: NetRecord[] = []              // 最新的在最前
  private idSeq: number = 0

  begin(method: string, url: string, requestBody: string): NetRecord {
    const rec = new NetRecord()
    rec.id = ++this.idSeq
    rec.method = method
    rec.url = url
    rec.startTime = Date.now()
    rec.requestBody = NetMonitorState.clip(requestBody)
    if (this.enabled) {
      this.records.unshift(rec)                 // 头插，最新在最上
      if (this.records.length > MAX_RECORDS) {  // 环形上限，超了砍尾
        this.records.splice(MAX_RECORDS, this.records.length - MAX_RECORDS)
      }
    }
    return rec
  }
  // finish / fail / addFrame / appendText / setCard / endStream ...
}

let monitorInstance: NetMonitorState | null = null
export function getNetMonitor(): NetMonitorState {
  if (monitorInstance === null) {
    monitorInstance = new NetMonitorState()
  }
  return monitorInstance
}
```

这里有个**让调用方零负担**的小设计：`begin()` 永远返回一个 `NetRecord`，但只有 `enabled` 时才把它塞进 `records`。release 包里 `enabled === false`，返回的是一条「孤儿记录」—— 调用方照样往上面 `addFrame`，但它不在任何列表里，随请求结束被 GC 掉。**调用方不用写一堆 `if (debug)` 判空**。

### 3.3 防 OOM：双重上限

调试工具最怕自己把 App 搞崩。两道保险：

```ts
const MAX_RECORDS: number = 50      // 最多留 50 条请求
const MAX_BODY_LEN: number = 51200  // 单段文本最多 50KB

private static clip(s: string): string {
  if (s.length <= MAX_BODY_LEN) return s
  return s.substring(0, MAX_BODY_LEN) + '\n...[已截断，原始长度 ' + s.length.toString() + ' 字符]'
}
```

请求体、响应体、每一帧、错误信息入库前都过一遍 `clip`。`fullText` 追加时也卡上限：

```ts
appendText(rec: NetRecord, chunk: string): void {
  if (rec.fullText.length < MAX_BODY_LEN) {
    rec.fullText += chunk
  }
}
```

---

## 四、在 SSE 出口埋钩子：重点抓「最后一帧的 card」

这是整件事的核心诉求。先回顾本 demo 的 SSE 协议（`data: {json}\n\n`）：

```text
data: {"chunk":"目的"}                                      ← 流式吐字
data: {"chunk":"地已为你选择..."}
...
data: {"done":true,"sessionId":"...","messageId":"...","card":{...}}   ← 结束帧带卡片
```

`SseHttpUtil` 原本就在 `dataReceive` 里按 `\n\n` 切帧、`JSON.parse`、分发 `onChunk` / `onDone`。我只在这些**已有的解析分叉点**上插上报，不改原解析逻辑：

```ts
static postStream(path: string, body: Record<string, Object>, callbacks: SseCallbacks): http.HttpRequest {
  // ① 请求开始：记下方法 / URL / 请求体
  const monitor = getNetMonitor()
  const rec = monitor.begin('SSE', ApiConstants.BASE_URL + path, JSON.stringify(body))

  const req = http.createHttp()
  // ... buffer / decoder ...

  req.on('dataReceive', (data: ArrayBuffer) => {
    // ... 按 \n\n 切帧 ...
    for (const part of parts) {
      const jsonStr = line.substring(5).trim()
      try {
        const frame = JSON.parse(jsonStr) as SseFrame
        if (frame.done === true) {
          // ② 结束帧：原样存帧 + 单独抽出 card / error
          monitor.addFrame(rec, 'done', jsonStr)
          if (frame.card) {
            monitor.setCard(rec, JSON.stringify(frame.card, null, 2))  // ← 我要的那张卡片
          }
          if (frame.error) {
            monitor.noteError(rec, frame.error)
          }
          callbacks.onDone({ /* ...原有透传... */ })
        } else if (frame.chunk !== undefined) {
          // ③ 普通帧：存帧 + 拼全文
          monitor.addFrame(rec, 'chunk', jsonStr)
          monitor.appendText(rec, frame.chunk)
          callbacks.onChunk(frame.chunk)
        }
      } catch (e) {
        // ④ 连 JSON 都解析不了的帧，原样存成 raw —— 这种最该被看见
        monitor.addFrame(rec, 'raw', jsonStr)
        LogUtil.e('SseHttpUtil', 'parse frame failed: ' + jsonStr)
      }
    }
  })

  req.on('dataEnd', () => {
    monitor.endStream(rec)   // ⑤ 流正常结束
    // ...原有 onDone 兜底...
  })

  req.requestInStream(/* ... */)
    .then((code: number) => {
      monitor.onSseStatus(rec, code)  // ⑥ 拿到 HTTP 状态码 → 进入 streaming
    })
    .catch((err: Error) => {
      monitor.fail(rec, JSON.stringify(err))  // ⑦ 建连失败 → 标红
      callbacks.onError(JSON.stringify(err))
      // ...
    })

  return req
}
```

几个细节值得记：

- **`card` 单独成一块存**：done 帧整体存进 `frames`（看原始报文），同时把 `card` 抽出来 `JSON.stringify(card, null, 2)` 格式化好放进 `cardJson`，详情页就能给它一个独立、好读的展示区，不用我在一长串 done 帧里找。
- **`raw` 类型是宝**：解析失败的帧最容易藏 bug（后端多吐了一行、编码问题、半个 JSON）。原来这种帧只打一条 error log 就没了，现在原样留在时间线里，一眼可见。
- **状态机的兜底**：理论上先 `requestInStream().then(code)` 拿到 200 才进 `streaming`，但首帧偶尔比 `then` 回调还早到。所以 `addFrame` 里也补了一句「如果还 pending 就转 streaming」，避免出现「已经在收帧了，状态还显示等待」。

`HttpUtil`（普通 GET/POST）同理，但要注意**别破坏原有的错误契约**：

```ts
.then((res: http.HttpResponse) => {
  getNetMonitor().finish(rec, res.responseCode, res.result as string)
  return JSON.parse(res.result as string) as ApiResponse<T>
})
.catch((err: Error) => {
  getNetMonitor().fail(rec, err.message ? err.message : JSON.stringify(err))
  throw err as Error   // ← 监控只是「旁路」，记完必须原样把错误抛回去
})
.finally(() => { req.destroy() })
```

监控是旁路观察者，**绝不能吞掉异常改变业务行为**。`catch` 里记一笔后立刻 `throw`，调用方拿到的拒绝和以前完全一样。

---

## 五、UI 层：悬浮球 + 半屏面板 + 帧时间线

### 5.1 悬浮球只在「收起态」占地方

```ts
@ComponentV2
export struct NetMonitorOverlay {
  private monitor: NetMonitorState = getNetMonitor()

  build() {
    if (this.monitor.enabled) {                 // release 包：整个组件渲染为空
      if (this.monitor.panelVisible) {
        NetMonitorPanel()                        // 展开态：全屏蒙层 + 半屏面板
      } else {
        Column() { /* NET + 请求数 */ }          // 收起态：只有一个 52×52 的球
          .position({ right: 12, bottom: 220 })
          .onClick(() => { this.monitor.panelVisible = true })
      }
    }
  }
}
```

为什么收起 / 展开分两个分支，而不是用一个常驻全屏容器靠透明度切？因为**全屏容器即使透明也会吃掉点击事件**，会挡住下面的页面。收起态只渲染那个小球，命中区域就只有球本身，底下页面照常能点。

### 5.2 挂载点：根页面从 Column 改成 Stack

```ts
// entry/src/main/ets/pages/Index.ets
Stack({ alignContent: Alignment.TopStart }) {
  HMNavigation({ navigationId: 'MainNavigation', homePageUrl: 'pages/Home', options: {} })
  NetMonitorOverlay()   // ← 盖在整个导航栈之上，切到任何页面都在
}
.width('100%').height('100%')
```

挂在 `HMNavigation` **同级、且在它之后**，`Stack` 后渲染的在上层，于是悬浮球浮在所有业务页面之上，跟着你在 App 里到处跑。

### 5.3 详情页：分块 + 帧时间线

详情页把一条记录拆成几个可复制的块：基本信息、请求体、卡片数据、回复全文、响应体、SSE 帧时间线。每帧一行，点一下展开看格式化 JSON：

```ts
@ComponentV2
struct NetFrameRow {
  @Param @Require frame: NetFrame
  @Local expanded: boolean = false

  build() {
    Column() {
      Row() {
        Text('#' + this.frame.seq.toString())          // 帧号
        Text('+' + this.frame.offsetMs.toString() + 'ms')  // 距开始多久到的
        Text(this.frame.type)                          // chunk / done / raw 彩色标签
      }
      Text(this.expanded ? prettyJson(this.frame.data) : this.frame.data)
        .maxLines(this.expanded ? 999 : 2)
        .copyOption(CopyOptions.LocalDevice)           // 可长按选中复制
    }
    .onClick(() => { this.expanded = !this.expanded })
  }
}
```

`+offsetMs` 这个相对时间偏移特别有用 —— 一眼看出**首帧多久才来**（首字延迟）、帧和帧之间是匀速吐还是卡顿。这就是 DevTools EventStream 那一列的平替。

文本用 `copyOption(CopyOptions.LocalDevice)`，配合每个块右上角的「复制」按钮（走 `pasteboard`），把请求体或 card JSON 一键拷出来贴到别处比对。

---

## 六、踩的坑

### 坑 1：`import BuildProfile from 'BuildProfile'` 在这个工程编不过

我想用 `BuildProfile.DEBUG` 控制采集开关。在别的工程里见过直接裸模块名导入：

```ts
import BuildProfile from 'BuildProfile'   // ❌ 本工程报错
```

编译直接挂：

```text
10505001 ArkTS Compiler Error
Cannot find module 'BuildProfile' or its corresponding type declarations.
```

原因是这个裸模块名要靠 hvigor 在编译期生成虚拟模块映射，**不同 hvigor 版本支持度不一样**。本工程不认。但每个模块根目录其实都有一个真实的 `BuildProfile.ets`（里面就有 `export const DEBUG = true`），改成相对路径指过去就好：

```ts
// common/src/main/ets/debug/NetMonitor.ets，从 debug/ 回到 common 根目录
import BuildProfile from '../../../../BuildProfile'   // ✅
```

> 教训：裸模块名导入能不能用是工程/工具链相关的，编不过先翻模块根目录有没有对应的 `.ets`，用相对路径兜底最稳。

### 坑 2：流式刷新依赖 @Trace，别在传参时把响应式弄丢

面板能「一帧帧自己冒出来」，全靠 `NetRecord` 里 `@Trace frames` 和 `@Trace fullText`。我特意让 UI **直接读 `record.frames` / `record.fullText`**，而不是先取出来当普通变量再传给子组件。ArkUI V2 里一旦把响应式字段「拆出来」传给非响应式参数，依赖关系就断了，UI 不会再跟着刷新。这个坑我之前在别处栽过，这次从一开始就避开。

### 坑 3：命令行编译打包报 `spawn java ENOENT`

想脱离 IDE 用命令行验证编译（这个工程没有 `hvigorw` 包装脚本），直接调 DevEco 自带的 node + hvigor：

```powershell
$env:DEVECO_SDK_HOME = "<DevEco>\sdk"
& "<DevEco>\tools\node\node.exe" "<DevEco>\tools\hvigor\bin\hvigorw.js" `
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

ArkTS 编译那一步过了，到打包签名 `PackageHap` 突然：

```text
Error Code: 00308018  spawn java ENOENT
```

打包阶段要调 `java`，而命令行环境里没有。把 DevEco 自带的 JBR 加进 `PATH` 即可：

```powershell
$env:Path = "<DevEco>\jbr\bin;" + $env:Path
```

> 一句话：ArkTS 编译用 node，**打包/签名用 java**，命令行编译记得两个都给到。

---

## 七、安全：这种面板只能留在 debug 包

面板会把**完整请求体和完整响应**明文显示出来，还能一键复制。这在生产包里是事故。两道门：

1. `enabled = BuildProfile.DEBUG` —— release 包 `false`，组件渲染为空、记录也不入列表。
2. 真要更严格，可以在 `entry` 挂载处也包一层构建判断，双保险。

我这个 demo 后端是局域网明文 HTTP、没有鉴权头，所以面板没做脱敏。但**正经项目的网络封装通常会对 `authorization` / `cookie` 这类敏感请求头做 `***` 脱敏**再展示/落日志 —— 如果你的 demo 带 token，给 `NetMonitorState` 也加一份敏感字段过滤再上线给同事用。

---

## 八、一句话心智模型

```text
网络收口到统一工具类 → 加监控只需埋一个点，业务零改动。
数据层一个 @ObservedV2 单例，会变的字段标 @Trace，UI 自动跟着刷。
begin 返回的记录永远不为空：release 时是孤儿对象，调用方不判空。
监控是旁路：catch 记一笔后必须原样 throw，绝不改业务行为。
明文报文只配活在 debug 包。
```

---

## 九、顺口溜

```text
想看请求像 F12，自己造个 Network 面板；
出口收口埋一钩，begin 一发记从头。

chunk 拼全文，done 抽卡片，
raw 帧别丢它最招坑；
偏移毫秒标每帧，首字延迟一眼明。

@Trace 在手 UI 自己跳，传参拆开就断了；
旁路记完原样抛，debug 才许看明文 —— release 一律渲染空。
```

---

## 十、参考

- [Network Kit — HTTP 数据请求（`@kit.NetworkKit`）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http)：`usingProxy` 默认行为、`requestInStream` 流式接口
- [网络诊断：Network 分析（DevEco Profiler）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-profiler-network)：官方性能视角的网络面板，和本文的业务视角互补
- [状态管理 V2 — @ObservedV2 / @Trace](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-observedV2-and-trace)：让流式帧实时刷新的底层机制
- [剪贴板（`@kit.BasicServicesKit` pasteboard）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-pasteboard)：一键复制报文
