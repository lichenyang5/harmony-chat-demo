import { PersistenceV2 } from '@kit.ArkUI'

/**
 * 主题状态：暗黑 / 亮色切换
 *
 * 设计思路：
 *   - @ObservedV2 + @Trace isDark：isDark 变化时，所有读到它的 build 函数自动重跑
 *   - getter 计算颜色 token：组件不再硬编码颜色字符串，改用 this.theme.bg 等
 *   - PersistenceV2 持久化：App 重启后主题记忆恢复
 *   - HomePage @Provider 提供，所有 Tab 组件 @Consumer 消费
 */
@ObservedV2
export class ThemeState {
  @Trace isDark: boolean = false

  // === 页面级背景 ===
  get bg(): string {
    return this.isDark ? '#1C1C1E' : '#F5F7FA'
  }

  // === 卡片 / 列表项背景 ===
  get surface(): string {
    return this.isDark ? '#2C2C2E' : '#FFFFFF'
  }

  // === 主文字 ===
  get textPrimary(): string {
    return this.isDark ? '#F2F2F7' : '#1C1C1E'
  }

  // === 次要文字 / 副标题 ===
  get textSecondary(): string {
    return this.isDark ? '#8E8E93' : '#888888'
  }

  // === 分割线 ===
  get divider(): string {
    return this.isDark ? '#38383A' : '#F0F0F0'
  }

  // === Tab 非选中项 ===
  get tabInactive(): string {
    return this.isDark ? '#636366' : '#AAAAAA'
  }

  // === 商品卡片占位图背景 ===
  get placeholderBg(): string {
    return this.isDark ? '#3A3A3C' : '#EEF2FF'
  }
}

// 全局单例：PersistenceV2 保证同一 key 复用同一实例，App 重启后恢复
export function getThemeState(): ThemeState {
  return PersistenceV2.connect(ThemeState, 'app_theme', () => new ThemeState())!
}
