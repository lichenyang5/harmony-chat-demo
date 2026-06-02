# 鸿蒙实战：安全高度 · 输入框贴键盘弹起 · Tab 底部导航全解

> 基于真实项目 `harmony-chat-demo` 的完整实现，覆盖三个高频痛点。  
> 代码路径均可在 `entry/src/main/ets/` 下找到。

---

## 一、为什么需要"安全高度"

鸿蒙手机底部存在两种系统占用区域：

| 导航模式 | 系统区域 | 高度参考 |
|---|---|---|
| 全面屏手势导航 | 手势横条（Home indicator） | ~34 px |
| 三键虚拟导航 | Back / Home / Recent 键栏 | ~126 px |
| 折叠屏 / 平板 | 视具体型号 | 不固定 |

如果 TabBar 高度写死 `56vp`，手势条的手机上图标会被遮住一半；输入框不处理键盘，键盘直接盖住输入框。两个问题，一套思路解决。

---

## 二、在应用生命周期获取安全高度

### 2.1 Ability 生命周期全景

```
UIAbility
  onCreate()              ← 初始化路由、全局配置，还没有 Window
  onWindowStageCreate()   ← Window 创建完成，这里拿 Window 对象
    └─ loadContent()      ← 异步加载页面，回调里安全区已稳定
  onForeground()          ← 应用切到前台
  onBackground()          ← 应用切到后台
  onWindowStageDestroy()  ← Window 销毁
  onDestroy()             ← Ability 销毁
```

**唯一正确时机：`onWindowStageCreate` 的 `loadContent` 回调**

- `onCreate` 时 Window 还不存在，调用 `getMainWindow` 会报错
- 直接在 `onWindowStageCreate` 里（回调外）调用，页面还未挂载，安全区数据可能不稳定
- `loadContent` 回调触发时，窗口内容已挂载，数据最终确定

### 2.2 EntryAbility 核心代码

```typescript
// entryability/EntryAbility.ets
onWindowStageCreate(windowStage: window.WindowStage): void {
  windowStage.loadContent('pages/Index', async (err) => {
    if (err.code) {
      hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err))
      return
    }
    // ✅ 页面挂载完成后立即读取安全区，存入 AppStorage 供全局使用
    const lastWindow = await windowStage.getMainWindow()
    WindowUtil.init(lastWindow)
  })
}
```

### 2.3 WindowUtil：读取两种安全区类型

鸿蒙提供 `window.getWindowAvoidArea(type)` 接口，返回一个 `AvoidArea` 对象，包含 `topRect / bottomRect / leftRect / rightRect`，单位均为 **px（物理像素）**，需要手动转成 vp。

```typescript
// utils/WindowUtil.ets
import { window } from '@kit.ArkUI'

export class WindowUtil {
  private static readonly KEY_BOTTOM_AVOID = 'windowUtil_bottomAvoid'
  private static readonly KEY_STATUS_BAR   = 'windowUtil_statusBar'

  static init(lastWindow: window.Window): void {
    try {
      // TYPE_SYSTEM：状态栏（topRect）+ 虚拟三键导航栏（bottomRect）
      const systemArea    = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      // TYPE_NAVIGATION_INDICATOR：全面屏手势横条（Home indicator）
      const indicatorArea = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)

      const statusBarHeight  = px2vp(systemArea.topRect.height ?? 0)
      const navBarHeight     = px2vp(systemArea.bottomRect.height ?? 0)
      const indicatorHeight  = px2vp(indicatorArea.bottomRect.height ?? 0)

      // 底部总避让 = 虚拟导航键 + 手势条（两者互斥，通常只有一个有值）
      AppStorage.setOrCreate(WindowUtil.KEY_BOTTOM_AVOID, navBarHeight + indicatorHeight)
      AppStorage.setOrCreate(WindowUtil.KEY_STATUS_BAR,   statusBarHeight)

      console.info('[WindowUtil] statusBar:', statusBarHeight,
        'navBar:', navBarHeight, 'indicator:', indicatorHeight)
    } catch (e) {
      console.error('[WindowUtil] init failed', JSON.stringify(e))
    }
  }

  // 底部避让高度（vp）：用于 TabBar / 悬浮按钮 padding
  static getBottomAvoidHeight(): number {
    return AppStorage.get<number>(WindowUtil.KEY_BOTTOM_AVOID) ?? 0
  }

  // 状态栏高度（vp）：用于全屏页面顶部 padding
  static getStatusBarHeight(): number {
    return AppStorage.get<number>(WindowUtil.KEY_STATUS_BAR) ?? 0
  }
}
```

**关键 API 解释：**

| API | 说明 |
|---|---|
| `AvoidAreaType.TYPE_SYSTEM` | 系统状态栏 + 虚拟三键导航栏 |
| `AvoidAreaType.TYPE_NAVIGATION_INDICATOR` | 全面屏手势横条（Home indicator） |
| `AvoidAreaType.TYPE_CUTOUT` | 挖孔屏摄像头区域 |
| `px2vp(px)` | 内置函数，物理像素转视口像素（vp = px / 设备密度） |
| `AppStorage.setOrCreate(key, val)` | 全局 KV 存储，整个应用生命周期内任何组件都能读取 |

> **为什么用 AppStorage 而不是全局变量？**  
> AppStorage 是鸿蒙框架管理的响应式存储，支持 `@StorageProp` 装饰器双向绑定，且在多 Ability 场景下不会丢失数据。

---

## 三、Tab Bar 正确适配底部安全高度

### 3.1 错误写法（图标被遮挡）

```typescript
// ❌ barHeight 固定，手势条手机上 TabBar 内容被遮
Tabs({ barPosition: BarPosition.End }) { ... }
  .barHeight(56)
```

### 3.2 正确写法

```typescript
// pages/HomePage.ets
@ComponentV2
export struct HomePage {
  // 从 AppStorage 读取底部安全高度，WindowUtil.init() 已在 Ability 里写入
  @Local bottomAvoid: number = WindowUtil.getBottomAvoidHeight()

  @Builder
  tabBarItem(index: number, label: string, icon: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(22)
        .fontColor(this.tabState.currentIndex === index ? '#007DFF' : '#AAAAAA')
      Text(label)
        .fontSize(10)
        .fontColor(this.tabState.currentIndex === index ? '#007DFF' : '#AAAAAA')
    }
    .width('100%')
    .height('100%')
    // ✅ 内容区加底部 padding，图标视觉上出现在手势条上方
    .padding({ bottom: this.bottomAvoid })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.tabState.currentIndex }) {
      TabContent() { HomeTabComp() }.tabBar(this.tabBarItem(0, '首页', '⌂'))
      TabContent() { ChatTabComp() }.tabBar(this.tabBarItem(1, 'AI助手', '✦'))
      TabContent() { ProfileTabComp() }.tabBar(this.tabBarItem(2, '我的', '○'))
    }
    .width('100%')
    .height('100%')
    // ✅ barHeight = 固定内容区 56 + 底部安全高度，整体撑开容纳手势条
    .barHeight(56 + this.bottomAvoid)
    .divider({ strokeWidth: 0.5, color: '#E8E8E8' })
    .onChange((index: number) => { this.tabState.currentIndex = index })
  }
}
```

**核心公式：**

```
TabBar 总高度 = 内容区高度（56vp）+ bottomAvoid
tabBarItem 内容 padding-bottom = bottomAvoid
```

这样内容区始终是 56vp，手势条区域只是空白占位，视觉上图标恰好在手势条上方。

### 3.3 `Tabs` 常用属性速查

| 属性 | 说明 |
|---|---|
| `barPosition: BarPosition.End` | TabBar 放底部（默认是顶部） |
| `barHeight(n)` | TabBar 总高度（含安全区） |
| `.tabBar(builder)` | 自定义每个 Tab 的样式（用 `@Builder` 函数） |
| `onChange((index) => {})` | 切换 Tab 时触发 |
| `index` | 当前激活的 Tab 索引，外部控制 |

---

## 四、输入框紧贴键盘弹起

这是聊天页面最常见的需求：**键盘弹起 → 输入框同步上移，恰好紧贴键盘顶部**。

### 4.1 系统默认行为的问题

鸿蒙默认的键盘避让模式是 `KeyboardAvoidMode.OFFSET`：键盘弹起时，系统自动把整个 Window 内容向上偏移键盘高度。

如果你**同时**又手动给 Column 加了 `padding.bottom = keyboardHeight`，就会出现**双重补偿**，输入框直接飞到屏幕顶部。

**解法：禁用系统默认避让，改用手动控制。**

### 4.2 两个场景的实现

#### 场景 A：ChatTabComp（Tab 内的嵌入式聊天）

难点在于：`keyboardHeight` 是从屏幕最底部算起的，包含了 TabBar 的高度；但 `ChatTabComp` 的 Column 只占 TabContent 区域（不含 TabBar）。

```typescript
// components/ChatTabComp.ets
@ComponentV2
export struct ChatTabComp {
  @Local keyboardHeight: number = 0
  private mainWindow: window.Window | null = null

  aboutToAppear(): void {
    // ✅ 第一步：禁用系统默认键盘避让
    // 系统默认会把 Window 上移，再手动加 padding 就会双重补偿
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
    } catch (_) {}

    this.initKeyboardListener()
  }

  aboutToDisappear(): void {
    // ✅ 恢复默认，避免影响其他页面（如登录页的表单）
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    } catch (_) {}
    try {
      this.mainWindow?.off('keyboardHeightChange')  // ✅ 取消监听，防止内存泄漏
    } catch (_) {}
    this.mainWindow = null
  }

  private async initKeyboardListener(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext()
      if (!ctx) return
      const win = await window.getLastWindow(ctx)
      this.mainWindow = win

      win.on('keyboardHeightChange', (heightPx: number) => {
        // 回调参数单位是 px，需要转成 vp
        const heightVp = heightPx > 0
          ? heightPx / display.getDefaultDisplaySync().densityPixels
          : 0

        // ✅ 用 animateTo 使输入框平滑上移，而不是生硬跳变
        this.getUIContext().animateTo(
          { duration: heightPx > 0 ? 300 : 250, curve: Curve.EaseOut },
          () => { this.keyboardHeight = heightVp }
        )
      })
    } catch (e) {
      console.error('[ChatTabComp] keyboard listener failed', JSON.stringify(e))
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('AI 助手').fontSize(18).fontWeight(FontWeight.Medium)
      }
      .width('100%').height(56).padding({ left: 20 })
      .backgroundColor(Color.White)

      // 消息列表，layoutWeight(1) 撑满剩余高度
      ChatListComp({ vm: this.vm }).layoutWeight(1)

      // 输入框
      ChatInputComp({ ... })
    }
    .width('100%')
    .height('100%')
    /**
     * ✅ 核心公式（Tab 内嵌场景）：
     *
     * keyboardHeight 是从屏幕最底计算的（含 TabBar）
     * 但 Column 只占 TabContent（不含 TabBar）
     *
     * 所以：padding.bottom = keyboardHeight - TabBar总高度
     *                      = keyboardHeight - (56 + bottomAvoid)
     *
     * Math.max(0, ...) 防止键盘收起时出现负值
     */
    .padding({ bottom: this.keyboardHeight > 0
      ? Math.max(0, this.keyboardHeight - 56 - WindowUtil.getBottomAvoidHeight())
      : 0
    })
  }
}
```

#### 场景 B：ChatPage（独立全屏聊天页）

全屏页没有 TabBar，公式更简单：

```typescript
// pages/ChatPage.ets
build() {
  Column() {
    // 顶部栏
    Row() { ... }.height(56)

    // 消息列表（撑满剩余空间，键盘弹起时自动收缩）
    ChatListComp({ vm: this.vm }).layoutWeight(1)

    // 输入框（始终在底部）
    ChatInputComp({ ... })
  }
  .width('100%')
  .height('100%')
  // ✅ 全屏场景直接用键盘高度作为底部 padding
  .padding({ bottom: this.keyboardHeight })
}
```

### 4.3 `layoutWeight(1)` 的作用

```
Column（height: 100%）
  ├─ Row（height: 56）         固定高度
  ├─ ChatListComp（weight: 1） ← 占满剩余所有空间
  └─ ChatInputComp             自身高度（约 56）
     └── padding.bottom = keyboardHeight  ← 键盘弹起时 Column 底部撑开
```

键盘弹起时，Column 的 padding.bottom 增大，ChatListComp 的可用高度缩小，自动滚动到最新消息，输入框恰好紧贴键盘顶部。这就是 `layoutWeight(1)` 的精妙之处：**不需要计算绝对高度，弹性撑满即可**。

### 4.4 键盘避让相关 API 速查

| API | 说明 |
|---|---|
| `KeyboardAvoidMode.OFFSET` | 默认：键盘弹起时系统自动把 Window 上移 |
| `KeyboardAvoidMode.NONE` | 禁用系统自动避让，完全由开发者手动控制 |
| `UIContext.setKeyboardAvoidMode(mode)` | 设置当前窗口的键盘避让模式 |
| `window.on('keyboardHeightChange', cb)` | 监听键盘高度变化，回调参数单位为 px |
| `window.off('keyboardHeightChange')` | 取消监听（必须在组件销毁时调用！） |
| `display.getDefaultDisplaySync().densityPixels` | 设备像素密度，用于 px → vp 转换 |
| `UIContext.animateTo({ duration, curve }, fn)` | 带动画的状态更新 |

> **px vs vp**  
> `keyboardHeightChange` 回调返回的是 **px（物理像素）**，而 ArkUI 布局使用 **vp（视口像素）**。  
> 转换公式：`vp = px / densityPixels`，也可以用内置函数 `px2vp(px)`（两者等价）。

---

## 五、购物车：跨页面传参与 pop 返回值

### 5.1 整体流程

```
HomePage（首页 Tab）
  │
  ├─ 点击商品卡片
  │     HMRouterMgr.push(pageUrl, param: product, onResult: cb)
  │
  ▼
ProductDetailPage（商品详情）
  │
  ├─ 点击「+」按钮：addCount++，setPopParam(addCount)
  │
  └─ 点击「加入购物车」：HMRouterMgr.pop()
        │
        └─ 触发 HomeTabComp 的 onResult(popInfo)
              cartCount += popInfo.result as number
```

### 5.2 HomeTabComp：push 传参 + onResult 接收

```typescript
// components/HomeTabComp.ets
@ComponentV2
export struct HomeTabComp {
  @Local cartCount: number = 0  // 购物车总数，跨路由累加

  private goDetail(product: Product): void {
    HMRouterMgr.push(
      {
        navigationId: NAV_ID,
        pageUrl: route.PAGE_PRODUCT_DETAIL,
        param: product          // ← push 传参：把整个 Product 对象带过去
      },
      {
        onResult: (popInfo: HMPopInfo) => {
          // ← pop 返回传参：详情页 setPopParam(n) 后 pop，result 就是 n
          const addCount = popInfo.result as number
          if (addCount > 0) {
            this.cartCount += addCount   // ← 累加到购物车总数
          }
        }
      }
    )
  }
}
```

### 5.3 ProductDetailPage：接收参数 + 设置返回值

```typescript
// pages/ProductDetailPage.ets
aboutToAppear(): void {
  // 读取 push 时传入的 param
  const param = HMRouterMgr.getCurrentParam()
  if (param) {
    this.product = param as Product
  }
}

private addToCart(): void {
  this.addCount++
  // 设置 pop 时返回的数据（还未 pop，可多次更新）
  HMRouterMgr.setPopParam(this.addCount)
}

private confirmAndBack(): void {
  HMRouterMgr.pop()  // pop 后 onResult 被调用，result = setPopParam 设置的值
}
```

### 5.4 购物车角标实现

```typescript
// 右上角角标（数量大于 0 时才显示）
Stack({ alignContent: Alignment.TopEnd }) {
  Text('🛒').fontSize(24)
  if (this.cartCount > 0) {
    Text(`${this.cartCount}`)
      .fontSize(10)
      .fontColor(Color.White)
      .width(16).height(16)
      .textAlign(TextAlign.Center)
      .backgroundColor('#FF4D4F')
      .borderRadius(8)
      .offset({ x: 4, y: -4 })  // 角标向右上偏移，超出购物车图标
  }
}
```

**Stack + offset** 是鸿蒙实现角标的标准做法：Stack 让角标叠在购物车图标上，`offset` 控制精确位置。

---

## 六、HMRouter：路由传参速查表

| 操作 | 方法 | 说明 |
|---|---|---|
| 跳转并传参 | `HMRouterMgr.push({ param })` | param 可以是任意对象 |
| 接收传参 | `HMRouterMgr.getCurrentParam()` | 在 `aboutToAppear` 中调用 |
| 设置返回值 | `HMRouterMgr.setPopParam(value)` | pop 前调用，可多次更新 |
| 返回并触发回调 | `HMRouterMgr.pop()` | 触发 push 时注册的 `onResult` |
| 接收返回值 | `onResult: (popInfo) => popInfo.result` | push 时注册的回调 |
| 注册全局拦截器 | `HMRouterMgr.registerGlobalInterceptor` | 防止重复跳转等场景 |

---

## 七、AppStorageV2：跨组件状态共享

Tab 状态（当前选中哪个 Tab）需要在 `HomePage`（控制显示）和多个子组件（可能需要切换 Tab）之间共享，使用 `AppStorageV2.connect` 实现全局单例：

```typescript
// viewmodel/AppTabState.ets
@ObservedV2
export class AppTabState {
  @Trace currentIndex: number = 0
}

// 全局单例：任何地方 connect 同一个 key，拿到的是同一个对象实例
export const tabState: AppTabState =
  AppStorageV2.connect(AppTabState, 'AppTabState', () => new AppTabState())!
```

```typescript
// pages/HomePage.ets
@Local tabState: AppTabState =
  AppStorageV2.connect(AppTabState, 'AppTabState', () => new AppTabState())!
```

**`AppStorageV2` vs `AppStorage` 的区别：**

| | AppStorage | AppStorageV2 |
|---|---|---|
| 存储单位 | 任意 KV | 类实例（类型安全） |
| 响应式 | `@StorageProp` 装饰器 | `@ObservedV2` + `@Trace` |
| 适合场景 | 简单数值（高度、颜色等） | 复杂状态对象（Tab 状态、用户信息） |

---

## 八、整体架构回顾

```
EntryAbility.onWindowStageCreate()
  └─ WindowUtil.init(window)          → AppStorage["bottomAvoid", "statusBar"]

Index.ets（@Entry）
  └─ HMNavigation（hmrouter 管理的路由容器）
       └─ LoginPage → HomePage（登录成功后跳转）

HomePage.ets
  ├─ bottomAvoid = WindowUtil.getBottomAvoidHeight()
  └─ Tabs（barHeight = 56 + bottomAvoid）
       ├─ HomeTabComp（首页：商品列表 + 购物车）
       │    └─ push → ProductDetailPage（传参 product，回调累加 cartCount）
       ├─ ChatTabComp（AI 助手：键盘避让 + 输入框贴键盘）
       └─ ProfileTabComp（我的）

ChatPage.ets（独立全屏聊天页，从 ChatTabComp push 进来）
  └─ 键盘避让逻辑同 ChatTabComp，但 padding.bottom = keyboardHeight（无需减去 TabBar）
```

---

## 九、常见踩坑总结

### 坑 1：双重键盘补偿

❌ `KeyboardAvoidMode.OFFSET`（默认）+ 手动 `padding.bottom = keyboardHeight` → 输入框飞走  
✅ 切换为 `KeyboardAvoidMode.NONE` + 手动 `padding.bottom`

### 坑 2：ChatTabComp 里键盘高度计算错误

❌ `padding.bottom = keyboardHeight` → 多减了 TabBar 高度，留出空隙  
✅ `padding.bottom = keyboardHeight - 56 - bottomAvoid`

### 坑 3：忘记在 aboutToDisappear 恢复键盘模式

❌ `KeyboardAvoidMode.NONE` 没有恢复 → 离开聊天页后，登录页表单输入时键盘也不避让了  
✅ `aboutToDisappear` 里 `setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)`

### 坑 4：忘记取消 keyboardHeightChange 监听

❌ 组件销毁后监听还在 → 内存泄漏，回调里的 `this` 成为悬空引用  
✅ `aboutToDisappear` 里 `mainWindow?.off('keyboardHeightChange')`

### 坑 5：在 onCreate 里读取 Window

❌ `UIAbility.onCreate` → Window 还不存在，`getMainWindow` 报错  
✅ `onWindowStageCreate` 的 `loadContent` 回调里调用

---

## 十、参考文档

- [Window - 鸿蒙官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-window)
- [UIContext.setKeyboardAvoidMode](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-uicontext)
- [Tabs 组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabs)
- [AppStorage](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-appstorage)
- [AppStorageV2](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-appstoragev2)
