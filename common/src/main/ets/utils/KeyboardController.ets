import { window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

/**
 * 键盘监听控制器（通用工具）。
 *
 * 软键盘弹起/收起时，业务页面通常需要动态调整底部 padding 防止输入框被遮挡。
 * 本类封装了 Window.on('keyboardHeightChange') 的注册/注销与单位换算（px → vp），
 * 由调用方提供回调决定如何响应（一般用 animateTo 触发布局动画）。
 *
 * 使用示例：
 * ```ts
 * private keyboardController: KeyboardController = new KeyboardController()
 *
 * aboutToAppear(): void {
 *   const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
 *   this.keyboardController.init(ctx, (heightVp, isShowing) => {
 *     this.getUIContext().animateTo(
 *       { duration: isShowing ? 300 : 250, curve: Curve.EaseOut },
 *       () => { this.keyboardHeight = heightVp }
 *     )
 *   })
 * }
 *
 * aboutToDisappear(): void {
 *   this.keyboardController.dispose()
 * }
 * ```
 */
export class KeyboardController {
  /** 持有 Window 引用以便 dispose 时注销事件，避免内存泄漏 */
  private mainWindow: window.Window | null = null

  /**
   * 初始化软键盘高度变化监听。
   *
   * @param ctx UIAbility 上下文（获取 Window 实例需要）
   * @param onHeightChange 高度变化回调
   *   - heightVp：键盘当前高度（vp 单位，键盘收起时为 0）
   *   - isShowing：键盘是否正在弹出（true = 弹出，false = 收起）
   */
  async init(ctx: common.UIAbilityContext, onHeightChange: (heightVp: number, isShowing: boolean) => void): Promise<void> {
    try {
      if (!ctx) {
        return
      }

      const win = await window.getLastWindow(ctx)
      this.mainWindow = win

      win.on('keyboardHeightChange', (heightPx: number) => {
        const isShowing = heightPx > 0
        // 将物理像素高度换算为密度无关像素（vp）
        const heightVp = isShowing
          ? heightPx / display.getDefaultDisplaySync().densityPixels
          : 0
        onHeightChange(heightVp, isShowing)
      })
    } catch (e) {
      console.error('[KeyboardController] init failed', JSON.stringify(e))
    }
  }

  /**
   * 注销键盘监听并释放 Window 引用。
   * 必须在 aboutToDisappear 中调用，防止内存泄漏。
   */
  dispose(): void {
    try {
      this.mainWindow?.off('keyboardHeightChange')
    } catch (_) {
    }
    this.mainWindow = null
  }
}
