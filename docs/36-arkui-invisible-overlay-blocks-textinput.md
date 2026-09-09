# ArkUI 隐形遮罩为何挡住 TextInput：zIndex、HitTestMode 与条件挂载排错

> 系列第 3 篇。本文复盘一个真实故障：历史抽屉关闭后完全看不见，但聊天输入框怎么点都没有反应，键盘也不会弹出。问题最终不在 `TextInput`，而在一个仍留在组件树中的全屏高层节点。

## 一、故障现象

完成历史会话抽屉后，聊天页面出现了一个很直接的问题：

- 输入框正常显示；
- placeholder 正常；
- 发送按钮也在原位置；
- 点击输入框没有光标；
- 系统软键盘不会弹出；
- 无法输入任何内容。

第一反应通常会检查：

- `TextInput` 是否被 `.enabled(false)`；
- `onChange` 是否写错；
- 键盘避让模式是否冲突；
- `ChatInputComp` 的 `@Param` 是否阻止双向更新。

但这几个方向都不能解释一个事实：**输入框连焦点都拿不到**。

当输入组件完全收不到点击时，应该先检查它上面是否存在覆盖层，而不是先修改输入逻辑。

## 二、引入问题的初始结构

为了让抽屉有关闭动画，最初的实现让 `ChatHistoryDrawerComp` 始终存在，只通过 `visible` 控制透明度和位移：

```ts
Stack() {
  // 聊天内容

  ChatHistoryDrawerComp({
    visible: this.historyDrawerVisible
  })
    .zIndex(10)
}
```

抽屉内部是一个全屏 `Stack`：

```ts
Stack({ alignContent: Alignment.TopEnd }) {
  Row()
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .opacity(this.visible ? 1 : 0)

  Column() {
    // 抽屉内容
  }
  .width('80%')
  .height('100%')
  .translate({ x: this.visible ? 0 : '100%' })
}
.width('100%')
.height('100%')
.opacity(this.visible ? 1 : 0)
```

视觉上看，关闭状态满足两个条件：

- 根节点透明度为 0；
- 80% 宽的面板平移到了屏幕右侧。

但它仍然是一个覆盖全屏、层级为 10 的组件。

## 三、第一个关键认知：透明不等于不存在

`opacity(0)` 只控制绘制结果，不代表组件：

- 从布局树移除；
- 失去自己的尺寸；
- 自动降低 `zIndex`；
- 自动停止触摸命中；
- 自动释放焦点相关影响。

可以把组件的几个维度分开理解：

| 维度 | 常见属性 | 回答的问题 |
| --- | --- | --- |
| 布局 | `width`、`height`、`layoutWeight` | 节点占多大空间 |
| 绘制 | `opacity`、`backgroundColor` | 节点看起来怎样 |
| 变换 | `translate`、`scale` | 节点怎样被绘制或变换 |
| 层级 | `zIndex` | 谁显示在谁上面 |
| 命中 | `hitTestBehavior` | 触摸事件先由谁处理 |
| 生命周期 | `if` 条件分支 | 节点是否存在于组件树 |

只修改“绘制”维度，不能推导出“命中”和“生命周期”也发生了变化。

## 四、第一次修复为什么不完整

第一版修复给抽屉根节点加了条件命中：

```ts
.hitTestBehavior(
  this.visible
    ? HitTestMode.Default
    : HitTestMode.None
)
```

看起来很合理，但本机 HarmonyOS SDK 对 `HitTestMode.None` 的定义是：

```text
Self not respond to the hit test for touch events,
but children respond to the hit test for touch events.
```

也就是说：

> `None` 只让当前节点自身不响应，子节点仍然可以参与触摸命中。

抽屉根节点下面仍有一个全屏遮罩 `Row` 和一个面板 `Column`，所以只设置根节点并不够。

于是进一步给遮罩和面板也增加条件：

```ts
Row()
  .width('100%')
  .height('100%')
  .hitTestBehavior(
    this.visible
      ? HitTestMode.Default
      : HitTestMode.None
  )
```

```ts
Column() {
  // 面板内容
}
.hitTestBehavior(
  this.visible
    ? HitTestMode.Block
    : HitTestMode.None
)
```

这一步仍未让设备上的输入框获得焦点。

原因是 `None` 对面板同样只影响面板自身，面板内部的标题、列表和按钮仍属于后代节点。更重要的是，自定义组件外部的修饰符还生成了一个额外包装层。

## 五、第二个关键认知：自定义组件修饰符可能产生包装节点

父组件中存在：

```ts
ChatHistoryDrawerComp({ ... })
  .zIndex(10)
```

在设备布局树中，这个修饰符对应了一个额外的 `__Common__` 节点：

```text
type: __Common__
zIndex: 10
bounds: [0,128][1260,2465]
hitTestBehavior: HitTestMode.Default
```

它的范围覆盖了整个聊天内容区。

即使抽屉内部根 `Stack` 已经透明，外层高层包装节点仍存在。继续只在 `ChatHistoryDrawerComp` 内部调整命中模式，不能保证这个包装节点一起消失。

项目也尝试过在内部根节点使用 API 23 可用的：

```ts
HitTestMode.BLOCK_DESCENDANTS
```

它用于阻止节点后代参与命中，但设备回归仍显示外部 `zIndex=10` 包装层存在，输入框依旧 `focused=false`。

这次失败给出了一个很实用的判断：

> 当问题来自“组件不该存在却仍然存在”时，继续叠加命中属性只是局部补丁；生命周期才是更可靠的解决层。

## 六、最终修复：关闭时移除整棵抽屉

最终实现不再让关闭的抽屉常驻，而是在父组件中条件挂载：

```ts
if (this.historyDrawerVisible) {
  ChatHistoryDrawerComp({
    visible: true,
    isGenerating: this.vm.isLoading,
    operationPending: this.sessionOperationPending,
    currentSessionId: this.vm.sessionId,
    onClose: () => {
      this.closeHistoryDrawer()
    },
    onSelectSession: (sessionId: string) => {
      return this.selectHistorySession(sessionId)
    },
    onNewSession: () => {
      this.requestNewSession()
    },
    onSessionDeleted: (sessionId: string) => {
      this.onHistorySessionDeleted(sessionId)
    },
    onOperationStateChange: (pending: boolean) => {
      this.sessionOperationPending = pending
    }
  })
    .zIndex(10)
    .transition(
      TransitionEffect.move(TransitionEdge.END)
        .combine(TransitionEffect.OPACITY)
        .animation({
          duration: 240,
          curve: Curve.EaseOut
        })
    )
}
```

关闭状态下，`if` 分支不成立，下面这些节点全部不存在：

- 自定义组件的 `__Common__` 包装层；
- 全屏抽屉根 `Stack`；
- 半透明遮罩；
- 80% 宽的面板；
- 面板中的标题、列表和按钮。

此时不需要猜测哪一层仍会命中，因为没有任何抽屉节点可以接收事件。

## 七、条件挂载后怎样保留动画

直接使用 `if` 并不意味着必须放弃动画。ArkUI 的 `transition` 可以处理组件插入和删除：

```ts
TransitionEffect.move(TransitionEdge.END)
  .combine(TransitionEffect.OPACITY)
  .animation({ duration: 240, curve: Curve.EaseOut })
```

它组合了两个效果：

- 从屏幕结束侧移动；
- 透明度渐变。

开关方法仍通过 `animateTo` 修改状态：

```ts
private openHistoryDrawer(): void {
  this.getUIContext().animateTo(
    { duration: 260, curve: Curve.EaseOut },
    () => {
      this.historyDrawerVisible = true
    }
  )
}

private closeHistoryDrawer(): void {
  this.getUIContext().animateTo(
    { duration: 220, curve: Curve.EaseIn },
    () => {
      this.historyDrawerVisible = false
    }
  )
}
```

状态变为 `true` 时组件进入树并播放出现转场；状态变为 `false` 时播放消失转场，随后从树中移除。

这种方式比“组件永远存在，只修改透明度”更符合临时覆盖层的生命周期。

## 八、为什么打开抽屉前要主动清理输入焦点

输入框已经获得焦点时打开抽屉，软键盘可能仍占据屏幕底部。抽屉高度和遮罩区域会因此变得不完整，用户也可能误以为仍在编辑。

打开前先清理焦点：

```ts
try {
  this.getUIContext().getFocusController().clearFocus()
} catch (error) {
  LogUtil.e(
    'ChatTabComp',
    'clear input focus failed: ' + JSON.stringify(error)
  )
}
```

然后再执行打开动画。

这段逻辑只负责“打开抽屉时收起键盘”，不能用来修复“关闭抽屉后输入框无法获得焦点”。后者仍然必须解决覆盖层命中问题。

## 九、不要把键盘避让误判成焦点问题

聊天页面原本就有手动键盘适配：

```ts
this.getUIContext().setKeyboardAvoidMode(
  KeyboardAvoidMode.NONE
)
```

监听键盘高度后更新底部 padding：

```ts
this.keyboardController.init(
  ctx,
  (heightVp: number, isShowing: boolean) => {
    this.getUIContext().animateTo(
      {
        duration: isShowing ? 300 : 250,
        curve: Curve.EaseOut
      },
      () => {
        this.keyboardHeight = heightVp
      }
    )
  }
)
```

```ts
.padding({
  bottom: this.keyboardHeight > 0
    ? Math.max(
        0,
        this.keyboardHeight - 56 -
          WindowUtil.getBottomAvoidHeight()
      )
    : 0
})
.expandSafeArea(
  [SafeAreaType.KEYBOARD],
  [SafeAreaEdge.BOTTOM]
)
```

这段代码回答的是“键盘出现后输入框应该移动到哪里”。

而本次故障发生在更早的阶段：点击没有到达 `TextInput`，键盘根本没有机会出现。

排查时应该按顺序区分：

```text
触摸是否命中 TextInput？
  ↓
TextInput 是否获得焦点？
  ↓
输入法窗口是否出现？
  ↓
键盘出现后布局是否正确避让？
```

不要在第一步失败时直接修改第四步。

## 十、怎样用设备布局树验证，而不是靠感觉

### 10.1 导出布局树

先查看设备：

```powershell
hdc list targets
```

导出当前布局：

```powershell
hdc -t <device-id> shell uitest dumpLayout `
  -p /data/local/tmp/chat-layout.json `
  -b com.example.myapplication
```

读取布局：

```powershell
hdc -t <device-id> shell cat `
  /data/local/tmp/chat-layout.json
```

重点搜索这些字段：

```text
type
bounds
origBounds
opacity
zIndex
hitTestBehavior
focused
visible
```

### 10.2 修复前的证据

输入框存在但未获得焦点：

```json
{
  "type": "TextInput",
  "hint": "说点什么...",
  "focused": "false",
  "text": "",
  "visible": "true"
}
```

同时存在全屏高层节点：

```json
{
  "type": "__Common__",
  "zIndex": "10",
  "bounds": "[0,128][1260,2465]",
  "hitTestBehavior": "HitTestMode.Default"
}
```

这比“我觉得有遮罩”更有说服力：输入框和遮挡节点的空间范围、层级和焦点状态都可以被直接观察。

### 10.3 注入点击并检查焦点

测试坐标需要根据设备分辨率和布局树中的 `bounds` 计算：

```powershell
hdc -t <device-id> shell uitest uiInput click <x> <y>
```

再次导出合并窗口布局：

```powershell
hdc -t <device-id> shell uitest dumpLayout `
  -p /data/local/tmp/chat-focus.json `
  -m true
```

修复后得到：

```json
{
  "type": "TextInput",
  "hint": "说点什么...",
  "focused": "true",
  "visible": "true"
}
```

合并窗口中还出现系统输入法：

```json
{
  "bundleName": "com.huawei.hmos.inputmethod",
  "visible": "true"
}
```

### 10.4 验证真实输入

输入框已经聚焦后注入文本：

```powershell
hdc -t <device-id> shell uitest uiInput text keyboard_ok
```

再次读取布局树，确认：

```json
{
  "focused": "true",
  "text": "keyboard_ok",
  "originalText": "keyboard_ok"
}
```

这条证据同时证明：

- 点击成功；
- 焦点成功；
- 输入法链路成功；
- 文本变化进入了 `TextInput`。

## 十一、完整的红绿回归过程

这次排错不是“改完能编译就算完成”，而是记录了原始症状的变化。

### 修复前

```text
点击输入框
TextInput.focused = false
TextInput.text = ""
输入法窗口不存在
```

### 使用局部 HitTestMode 后

```text
编译成功
点击输入框
TextInput.focused = false
```

说明假设或修复范围仍不完整，不能宣布修复。

### 条件移除整棵抽屉后

```text
关闭状态 overlays = []
点击输入框
TextInput.focused = true
系统输入法 visible = true
输入 keyboard_ok
TextInput.text = "keyboard_ok"
```

### 再验证抽屉开关

```text
打开历史抽屉
点击遮罩关闭
确认 zIndex=10 的抽屉包装层消失
再次点击输入框
TextInput.focused = true
系统输入法 visible = true
```

只有最后一组结果真正覆盖了原始问题和功能回归。

## 十二、覆盖式组件的通用设计规则

这个问题不只会出现在聊天抽屉，还常见于：

- Dialog；
- 自定义 Sheet；
- 全屏 Loading；
- 图片预览；
- 新手引导蒙层；
- 下拉菜单；
- Toast 容器；
- 页面级网络状态浮层。

可以遵循以下规则。

### 规则 1：短期覆盖层关闭后优先退出组件树

如果组件关闭后不需要保留复杂局部状态，优先使用：

```ts
if (visible) {
  OverlayComp()
    .transition(...)
}
```

而不是让它永久全屏存在。

### 规则 2：不要把透明度当作交互开关

`opacity(0)` 只能表达“看不见”，不能单独表达“不可交互”。

### 规则 3：检查所有祖先和包装节点

子组件内部没有明显遮挡，不代表外部修饰符没有创建高层节点。调试时从 `TextInput` 向上检查整个层级，而不是只读某一个 `.ets` 文件。

### 规则 4：明确理解每个 HitTestMode

尤其不要凭名字猜 `None`。在当前 SDK 中，它允许子节点继续响应。需要结合父子层级、兄弟节点和实际 API 版本判断。

### 规则 5：用原始症状作为完成标准

对于“键盘弹不出”：

- 编译通过不是完成；
- 页面能打开不是完成；
- 输入框可见不是完成；
- 必须验证焦点、输入法窗口和文本输入。

## 十三、小结

本次问题的根因可以压缩成一句话：

> 抽屉只在视觉上关闭了，但带有高 `zIndex` 的全屏组件树仍存在，所以触摸事件到不了下面的 `TextInput`。

最终修复也可以压缩成一句话：

> 用条件挂载控制覆盖层生命周期，再用 `transition` 补回插入和删除动画。

真正值得学习的是排错顺序：先观察焦点，再检查覆盖层，再读取设备布局树，最后用同一个交互步骤做红绿回归。这样才能避免“编译成功但用户仍然点不进去”的假修复。

上一篇：[RDB、会话切换、左滑删除与并发保护](./35-harmony-chat-history-drawer-session-management.md)  
系列索引：[HarmonyOS 聊天会话抽屉重构系列](./33-harmony-chat-history-drawer-series-index.md)
