import { PersistenceV2 } from '@kit.ArkUI'

/**
 * 全局主题状态：亮色 / 暗黑
 *
 * 放在 common 模块的原因：
 * - entry 模块依赖 common
 * - chat 模块也依赖 common
 * - 所以主题状态放 common 后，entry 和 chat 都可以直接复用
 */
@ObservedV2
export class ThemeState {
  @Trace isDark: boolean = false

  // ================= 页面 / 容器 =================

  get bg(): string {
    return this.isDark ? '#1C1C1E' : '#F5F7FA'
  }

  get surface(): string {
    return this.isDark ? '#2C2C2E' : '#FFFFFF'
  }

  get cardBg(): string {
    return this.surface
  }

  get placeholderBg(): string {
    return this.isDark ? '#3A3A3C' : '#EEF2FF'
  }

  // ================= 文字 =================

  get textPrimary(): string {
    return this.isDark ? '#F2F2F7' : '#1C1C1E'
  }

  get textSecondary(): string {
    return this.isDark ? '#C7C7CC' : '#666666'
  }

  get textTertiary(): string {
    return this.isDark ? '#8E8E93' : '#AAAAAA'
  }

  get textPlaceholder(): string {
    return this.isDark ? '#8E8E93' : '#CCCCCC'
  }

  // ================= 边框 / 分割线 / 阴影 =================

  get divider(): string {
    return this.isDark ? '#38383A' : '#EBEBEB'
  }

  get border(): string {
    return this.isDark ? '#48484A' : '#F0F0F0'
  }

  get shadowColor(): string {
    return this.isDark ? '#66000000' : '#0A000000'
  }

  get drawerShadowColor(): string {
    return this.isDark ? '#99000000' : '#33000000'
  }

  // ================= 品牌色 / 语义色 =================

  get primary(): string {
    return '#007DFF'
  }

  get onPrimary(): string {
    return '#FFFFFF'
  }

  get danger(): string {
    return '#FF4D4F'
  }

  get dangerBg(): string {
    return this.isDark ? '#3A1F20' : '#FFF1F0'
  }

  get dangerBorder(): string {
    return this.isDark ? '#7A2E30' : '#FFCCC7'
  }

  get onDanger(): string {
    return '#FFFFFF'
  }

  get warningBg(): string {
    return this.isDark ? '#332A12' : '#FFFBF0'
  }

  get warningBorder(): string {
    return this.isDark ? '#66521A' : '#FFE8A0'
  }

  get disabledBg(): string {
    return this.isDark ? '#3A3A3C' : '#CCCCCC'
  }

  // ================= 表单 =================

  get inputBg(): string {
    return this.isDark ? '#3A3A3C' : '#F5F5F5'
  }

  get inputText(): string {
    return this.textPrimary
  }

  get placeholderText(): string {
    return this.textTertiary
  }

  // ================= 聊天气泡 =================

  get assistantBubbleBg(): string {
    return this.isDark ? '#3A3A3C' : '#F0F0F0'
  }

  get userBubbleBg(): string {
    return this.primary
  }

  get loadingBubbleBg(): string {
    return this.assistantBubbleBg
  }

  // ================= Tab =================

  get tabActive(): string {
    return this.primary
  }

  get tabInactive(): string {
    return this.isDark ? '#8E8E93' : '#AAAAAA'
  }

  // ================= 按钮 =================

  get secondaryButtonBg(): string {
    return this.isDark ? '#3A3A3C' : '#F0F0F0'
  }

  get secondaryButtonText(): string {
    return this.isDark ? '#F2F2F7' : '#333333'
  }

  // ================= 信息块 =================

  get infoBg(): string {
    return this.isDark ? '#242B3D' : '#F8F9FF'
  }

  get infoBorder(): string {
    return this.isDark ? '#35415E' : '#DDEAFF'
  }
}

/**
 * 全局主题单例
 * PersistenceV2 会根据 app_theme 这个 key 复用同一个实例，并支持持久化。
 */
export function getThemeState(): ThemeState {
  return PersistenceV2.connect(ThemeState, 'app_theme', () => new ThemeState())!
}