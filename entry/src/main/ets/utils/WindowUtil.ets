import { window } from '@kit.ArkUI'

/**
 * 屏幕安全区工具
 *
 * 两个问题的根源：
 *   1. 底部导航条（手势条/虚拟按键）遮挡 TabBar → 需要 bottomAvoidHeight 加 padding
 *   2. 键盘弹出遮挡输入框 → 需要监听 keyboardHeightChange 动态调整
 *
 * 使用方式：
 *   1. EntryAbility.onWindowStageCreate 调用 WindowUtil.init(lastWindow)
 *   2. 组件中调用 WindowUtil.getBottomAvoidHeight() 获取底部避让高度
 *   3. 键盘监听放到具体组件里（见 ChatTabComp / ChatPage）
 */
export class WindowUtil {
  // AppStorage key（与公司 ScreenUtil 设计一致）
  private static readonly KEY_BOTTOM_AVOID = 'windowUtil_bottomAvoid'
  private static readonly KEY_STATUS_BAR = 'windowUtil_statusBar'

  /**
   * 在 EntryAbility.onWindowStageCreate 中调用一次
   * 把系统区域高度存入 AppStorage，供全局组件使用
   */
  static init(lastWindow: window.Window): void {
    try {
      // TYPE_SYSTEM：状态栏 (topRect) + 虚拟导航键 (bottomRect)
      const systemArea = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      // TYPE_NAVIGATION_INDICATOR：手势导航条 / Home indicator
      const indicatorArea = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)

      const statusBarHeight = px2vp(systemArea.topRect.height ?? 0)
      const navBarHeight = px2vp(systemArea.bottomRect.height ?? 0)
      const indicatorHeight = px2vp(indicatorArea.bottomRect.height ?? 0)

      // 底部总避让 = 虚拟导航键 + 手势条（两者互斥，通常只有一个有值）
      AppStorage.setOrCreate(WindowUtil.KEY_BOTTOM_AVOID, navBarHeight + indicatorHeight)
      AppStorage.setOrCreate(WindowUtil.KEY_STATUS_BAR, statusBarHeight)

      console.info('[WindowUtil] init — statusBar:', statusBarHeight,
        'navBar:', navBarHeight, 'indicator:', indicatorHeight)
    } catch (e) {
      console.error('[WindowUtil] init failed', JSON.stringify(e))
    }
  }

  /**
   * 底部避让高度（vp）
   * 用于 TabBar / 悬浮按钮 / 底部弹窗 的 padding，防止被系统导航条遮挡
   */
  static getBottomAvoidHeight(): number {
    return AppStorage.get<number>(WindowUtil.KEY_BOTTOM_AVOID) ?? 0
  }

  /**
   * 状态栏高度（vp）
   * 用于全屏页面顶部内容的 padding
   */
  static getStatusBarHeight(): number {
    return AppStorage.get<number>(WindowUtil.KEY_STATUS_BAR) ?? 0
  }
}
