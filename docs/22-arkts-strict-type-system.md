# ArkTS 严格类型系统：我答错 2 道题后才真正搞懂的几条规则

> 项目：`MyApplication`（AI 助手 demo）
> 对照代码：`chat/src/main/ets/models/chatModel.ets`
> 主题：入职第四周了，我居然才系统过一遍 ArkTS 的类型规则。之前一直以为它跟 TypeScript 差不多 —— 直到做 5 道自测题答错 2 道，才意识到这是**两种语言**。本篇按"为什么 → 是什么 → 我踩过的坑"的顺序，把 ArkTS 严格类型系统的核心规则梳理一遍，全部对照 `chatModel.ets` 的真实代码。

---

## 一、一句话定位 ArkTS

```text
ArkTS = TypeScript 的「严格子集」。
设计目标只有一个：
让编译器在【编译期】就能确定每个变量的精确类型和内存布局。
```

所有奇怪的限制都从这一句话推出来：

- 为什么禁 `any`？编译期类型不能含糊
- 为什么对象字面量要带类型？编译期要知道 shape
- 为什么 class 字段必须有默认值？编译期要确定内存布局
- 为什么名义类型不是结构类型？编译期要能区分两个长得一样的 class

理由都是同一个 —— **AOT 编译 + 跨线程 Sendable + UI 状态追踪** 需要编译器有足够的静态信息。

记住这句话，遇到不理解的限制都能反推出来。

---

## 二、七大核心差异

下面每条 = TS 写法 / ArkTS 写法 / 为什么 / 我项目里的对照。

### 2.1 禁 `any` / `unknown`

```ts
// TS 合法
let data: any = fetchSomething()
let result: unknown = JSON.parse(str)

// ArkTS 禁止
```

**为什么**：`any` 让所有类型检查失效，编译器没法做 AOT。

**我 chatModel.ets 里的处理**（line 82）：

```ts
@Trace card: Object | null = null
```

我用 `Object` 而不是 `any` —— 这是合规的"逃生口"，但 `Object` 已经丢失了精度。更好的写法是：

```ts
@Trace card: AgentCard | null = null   // 用 interface 兜
```

我之所以没这么写，是因为子卡片字段差异大、上层想统一收口。**这是主动牺牲精度的权衡，不是不知道**。

### 2.2 对象字面量必须有显式类型

```ts
// TS 合法（推断成 { x: number }）
const a = { x: 1 }

// ArkTS 必须
const a: SomeType = { x: 1 }
// 或者
class SomeType { x: number = 0 }
const a = new SomeType()
```

**为什么**：编译器不靠"推断"过日子，结构必须先声明。

### 2.3 名义类型，不是结构类型

这条最容易踩。

```ts
class A { x: number = 0 }
class B { x: number = 0 }

const a: A = new A()
const b: B = a   // TS 合法（duck typing），ArkTS 报错
```

**为什么**：编译器需要能精确识别"这个对象是哪个类的实例"，结构相同不够。

**我 chatModel.ets 里的真实例子**（line 75 和 96）：

```ts
@ObservedV2
export class ChatMessage {       // 响应式版本
  id: string = ''
  role: string = ''
  @Trace content: string = ''
  // ...
}

export class ChatMessagePlain {  // 持久化版本
  id: string = ''
  role: string = ''
  content: string = ''
  // ...
}
```

两个 class **字段几乎一样**，但 **不能互相赋值**：

```ts
const m: ChatMessage = new ChatMessage()
const p: ChatMessagePlain = m   // ArkTS 编译报错
```

所以我 `ChatHistoryController` 里读历史回来必然要写一个"手动转换"的函数 —— **这就是名义类型逼出来的工程模式**。

### 2.4 禁止给对象动态加属性

```ts
class User { name: string = '' }
const u = new User()
u.age = 18   // ArkTS 报错（User 上没声明 age）
```

**为什么**：AOT 编译时对象的内存布局就定下来了，不能运行时长字段。

**实战影响**：
- 不能写 `obj[someKey] = value` 这种动态 KV（除非 obj 类型是 `Record<string, X>` 或 `Map<string, X>`）
- 序列化/反序列化时要谨慎，`JSON.parse` 回来的对象**不是**我的 class 实例，是 plain object

### 2.5 函数返回类型必须显式

```ts
// TS 推断成 number
function add(a: number, b: number) { return a + b }

// ArkTS 推荐显式（严格模式下强制）
function add(a: number, b: number): number { return a + b }
```

**为什么**：编译期类型确定 + 重构时改了实现不会偷偷改签名。

### 2.6 类必须有 constructor 或所有字段有默认值

```ts
// ArkTS 禁止：字段没默认值 + 没 constructor
class Bad {
  x: number   // 报错
}

// ArkTS 合法 A：字段都有默认值（我 chatModel 全是这样）
class Good1 {
  x: number = 0
}

// ArkTS 合法 B：显式 constructor 初始化
class Good2 {
  x: number
  constructor(x: number) { this.x = x }
}
```

**为什么**：保证对象创建瞬间所有字段都有确定值，没有"中途未定义"的状态。

**我 chatModel 全部走方案 A** —— 字段全给默认值 → 隐式无参构造器 → 编译器满意。这是 ArkTS 项目里**最常见的 class 写法**。

### 2.7 标准库只支持子集

不支持的常见 API：

- `Date.prototype.toLocaleString(...locale)` 部分参数
- 部分 `Object` 上的反射 API（`Object.defineProperty` / `Object.setPrototypeOf` 等）
- 部分 `Reflect`、`Proxy`
- 老 Date API（`getYear` 这种）

**为什么**：这些 API 大多依赖动态原型链，跟 ArkTS 的静态决定论冲突。

> 一个有趣的连锁反应：ArkUI 之所以用 `@Trace` / `@ObservedV2` 装饰器做响应式，而不是 Vue / MobX 那样的 Proxy，就是因为 Proxy 在 ArkTS 里被限制了。

---

## 三、interface vs class —— 实战决策树

这一条是新手最容易混的。

| 维度 | `interface` | `class` |
|---|---|---|
| 运行时存在 | ❌ 编译后消失（纯类型契约） | ✅ 有对应的运行时构造器 |
| 能 `new` | ❌ | ✅ |
| 能加装饰器（@ObservedV2 / @Sendable / @Param） | ❌ | ✅ |
| 字段是否必须初始化 | 不要求（只是签名） | 要求（默认值或 constructor） |
| 方法实现 | ❌（只能声明） | ✅ |
| 跨模块传递时 | 编译期检查后消失 | 真实对象 |

**实战决策树**：

```text
要不要 new 它？
├─ 不要（只是 DTO 类型契约）→ interface
└─ 要 new
    ├─ 要给它加响应式（@ObservedV2 / @Trace）  → class
    ├─ 要传给 @Param                          → class
    ├─ 要跨线程发给 TaskPool                  → class + @Sendable
    └─ 都不要、就是数据袋子                   → class（字段默认值，无方法）
```

**对照我 chatModel.ets**：

```ts
export interface AgentCard { type: string }       // 纯类型契约，子卡片共享的 shape
export class PickupPoint { /* ... */ }            // 纯数据袋子
export class PickupCard { /* ... */ }             // 纯数据袋子
export class TripCard { /* ... */ }               // 要传给 @Param card: TripCard
@ObservedV2 export class ChatMessage { /* ... */ } // 响应式 → 必须 class
export class ChatMessagePlain { /* ... */ }       // 持久化 → JSON 友好的 class
export class ChatHistoryItem { /* ... */ }
export class ChatSession { /* ... */ }
```

我之前是凭"直觉"这么写的，过完今天的内容才意识到 —— **我已经按这套决策树在写了，只是没系统化**。

---

## 四、严格模式下的 4 个小陷阱

这一节是我今天**真正学到东西**的地方。前面三节我都"以为我懂"，做题才发现这几条没意识到。

### 4.1 对象字面量不能初始化 class（最大的坑）

这条我做 Q3 题时漏了。我以为只要给字面量加类型注解就行：

```ts
// 我以为这样就够了
const msg: ChatMessage = { id: '', role: '', content: '', createTime: 0 }
```

**实际上 ArkTS 报错**。理由：

```text
class 实例是带「类型烙印」的（名义类型 + 可能有装饰器钩子），
不是单纯的 plain object。
对象字面量构造出来的是 plain object，编译器拒绝把它当成 class 实例。
```

正确写法：

```ts
const msg: ChatMessage = new ChatMessage()
msg.id = ''
msg.role = ''
msg.content = ''
msg.createTime = 0
```

**例外**：如果接收方是 `interface`（比如 `AgentCard`），字面量赋值是允许的 —— 因为 interface 编译后不存在，本质上还是 plain object。

记忆口诀：**`new` 构造 class，字面量构造 interface / 简单 record**。

### 4.2 class 字段不能用逗号分隔（我 Q5 答错的）

Q5 题我写：

```ts
export class A {
  id:string='',         // 错：逗号
  name:string='',       // 错：逗号
  createTime:number=0
}
```

**ArkTS / TS 的 class 字段分隔用分号 `;` 或换行无标点，不能用逗号**。逗号是 interface 和 object literal 的语法。

正解：

```ts
export class A {
  id: string = ''
  name: string = ''
  createTime: number = 0
}
```

或者带分号：

```ts
export class A {
  id: string = '';
  name: string = '';
  createTime: number = 0;
}
```

**对照规则速查**：

| 语法 | 字段分隔符 |
|---|---|
| `class` | 分号 `;` 或换行无标点 |
| `interface` | 分号 `;` / 逗号 `,` / 换行无标点 三选一 |
| object literal `{ }` | 逗号 `,` |
| `type` literal | 分号 `;` 或逗号 `,` |

class 和 interface 的字段分隔规则**不一样**，这是历史包袱（来自 TS / Java / C# 的取舍）。

### 4.3 平行 class 不能 `as` 互转

平时常做的"两个长得一样的类型互转"，在 ArkTS 里要小心：

```ts
// TS 在结构类型下可以
const p: ChatMessagePlain = msg as ChatMessagePlain

// ArkTS 名义类型下，编译器拒绝（或要走 as unknown as 中介）
```

即使强转过去，原对象还是带 `@Trace` 装饰器的代理。后面 `JSON.stringify` 时可能输出代理对象而不是原值。

**正解** —— 写一个明确的 `toPlain` 转换函数，逐字段搬：

```ts
function toPlain(msg: ChatMessage): ChatMessagePlain {
  const p = new ChatMessagePlain()
  p.id = msg.id
  p.role = msg.role
  p.content = msg.content
  p.createTime = msg.createTime
  p.sessionId = msg.sessionId
  p.card = msg.card
  return p
}
```

这就是 `chatModel.ets` 顶部注释里写的 _"保存历史记录时，必须先转成 ChatMessagePlain"_ 在工程上长什么样。

### 4.4 容器必须显式泛型

```ts
// 缺类型
const m = new Map()
const s = new Set()
const arr = []

// 显式泛型
const m: Map<string, number> = new Map()
const s: Set<string> = new Set()
const arr: ChatMessage[] = []
const arr2: Array<ChatMessage> = []   // 等价

// 对象当 Map 用，要用 Record
const cache: Record<string, number> = {}
cache['key'] = 1
```

---

## 五、做 5 道自测题的反思 — 我答错的地方

### Q1（60%）：抽象 vs 具体联合的扩展性 / 精度权衡，我答反了

题目：把 `ChatMessage.card` 从 `Object | null` 改成更精确的类型。给两个方案。

我以为：`AgentCard | null` 更精准、`PickupCard | TripCard | null` 更全面。

**反了**：

| 方案 | 精度 | 扩展性 |
|---|---|---|
| `AgentCard \| null` | **低**（只保证有 type，访问子字段还要 as） | **高**（加新卡只 implements，不动 ChatMessage） |
| `PickupCard \| TripCard \| null` | **高**（每个子字段都精确） | **低**（每加一种就要改 union） |

**学到**：抽象类型 = 扩展强 + 精度低，具体联合 = 精度高 + 每加一种都得改。**经典工程权衡**。

### Q2（70%）：as 不是被全禁，而是名义类型限制

题目：写 `toPlain(msg: ChatMessage): ChatMessagePlain`。为啥不能 `return msg as ChatMessagePlain`？

我答："严格模式不能用 as，函数必须指明返回类型"。

**真相**：
- `as` 不是被全禁 —— 子类 → 父类、interface → 实现类是允许的
- 真正的问题是 ArkTS **名义类型**下，`ChatMessage` 和 `ChatMessagePlain` 是两个独立 class，无继承关系，跨名义强转不允许
- 退一步，就算强转过去，**@Trace 装饰器的代理身份**也带出来了，JSON 序列化要爆炸

**学到**：as 限制的是"跨名义类型的不安全强转"，不是 as 本身被禁。

### Q3（80%）：对象字面量不能 new class 是最大坑

我抓到"函数没返回类型 + msg 没类型"，但说"简写不可以"是错的（ES6 shorthand 在 ArkTS 是允许的）。

**漏掉的最大坑**：差异 4.1 —— 对象字面量根本不能初始化 class。

### Q4（85%）：核心对，可以更精准

我答"持久化时序列化丢失"，方向对。**更精准**：

1. `@Trace` 装饰器把字段变成 getter/setter 代理，`JSON.stringify` 输出代理状态而非原值
2. 反序列化也无法重建装饰器钩子
3. 所以持久化必须用 plain 版本 —— **职责分离：UI 响应式 vs 存储 JSON 友好**

### Q5（50%）：class 字段用了逗号

差异 4.2 —— class 字段必须分号 / 换行，不能逗号。这是基础语法错。

---

## 六、`chatModel.ets` 里我已经踩对的模式

回头看自己 1 个月前写的 chatModel，按今天学到的 ArkTS 规则**对照检查**，没意识到自己已经踩对了好几条：

| 规则 | 我代码里的体现 |
|---|---|
| 禁 any → 用 Object 兜底 | `@Trace card: Object \| null = null` |
| class 字段必须初始化 | 所有 class 字段都给了默认值 |
| 对象字面量必须有类型 | 没出现裸 object literal |
| interface 用于纯契约 | `AgentCard` 是 interface |
| class 用于带响应式 / 实例化 | `ChatMessage` / `TripCard` 都是 class |
| 双胞胎模式：响应式版 + 持久化版 | `ChatMessage` ↔ `ChatMessagePlain` |
| @Trace 字段不进 JSON | `ChatSession.messages: ChatMessagePlain[]` 而非 ChatMessage[] |

唯一**应该补但还没补**的：明确的 `toPlain(msg)` / `fromPlain(p)` 两个转换函数。现在转换逻辑应该是散在 ChatHistoryController 里的 —— **今天补完整理一下**。

---

## 七、一句话心智模型

```text
ArkTS 里写代码，每个变量先问三件事：
  1. 这个变量是什么类型？
  2. 这个 class 的所有字段是不是从一出生就有值？
  3. 这个赋值有没有在类型系统里能被静态证明？

三个都「是」→ 编译通过；
任何一个含糊 → 编译报错。
```

---

## 八、顺口溜

```text
ArkTS 写 class 三个永远：
  永远 new，永远逐字段赋值，永远显式写类型。

字段分隔三个不一样：
  class 用分号或换行，interface 三种都行，字面量必须逗号。

跨类型转换两个不可以：
  平行 class 不可以 as，对象字面量不可以当 class。
```

---

## 九、参考

- [ArkTS 概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-overview)
- [TypeScript 到 ArkTS 迁移指南（核心约束清单）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/typescript-to-arkts-migration-guide)
- [ArkTS 类与对象](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-classes-and-objects)
- [ArkTS 编码规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-coding-style-guide)

---

## 十、TODO（今天剩下时间做完）

- [ ] 扫一遍 chat/entry 两个模块下所有 class，确认字段分隔符没有逗号
- [ ] 扫一遍所有 `new XxxClass()` 之外的实例化方式，看有没有偷偷用对象字面量
- [ ] 在 chatModel.ets 末尾补 `toPlain(msg)` / `fromPlain(p)` 两个转换函数，把散在 controller 里的逻辑收口
- [ ] 给 `ChatMessage.card` 的类型从 `Object | null` 升级到 `AgentCard | null`，看一下访问 `card.title` 会编译报错（验证我对 ArkTS 类型守卫的理解）
